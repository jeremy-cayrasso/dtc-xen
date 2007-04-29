<?php
// Daemon for pulling stats from dtc-xen servers
// Damien Mascord <damien@gplhost.com>

include "/usr/share/dtc/shared/inc/nusoap.php";
include "/usr/share/dtc/shared/inc/vps.php";

/**
 * Run the current script as a daemon.  Used mostly (always?) for command line scripts.
 *
 * @author      Matt Curry <matt@mcurry.net>
 * @version     1.0.0
 */
 
function daemonize() {
   $child = pcntl_fork();
   if($child) {
       exit; // kill parent
   }
   posix_setsid(); // become session leader
   chdir("/");
   umask(0); // clear umask
   return posix_getpid();
}

// daemonize the process so it's sits in the background
// daemonize();


error_reporting(E_ALL);

//TODO: include autoSQLconfig.php instead of these values

$conf_mysql_host="localhost";
$conf_mysql_login="root";
$conf_mysql_pass="MYSQL_ROOT_PASSWORD";
$conf_mysql_db="dtc";
#$conf_time_delay_in_seconds=10*60;
$conf_time_delay_in_seconds=20;

// TODO: need to pull this from dtc config
$pro_mysql_vps_server_table="vps_server";
$pro_myslq_vps_stats_table="vps_stats";

function connect2base(){
	global $conf_mysql_host;
	global $conf_mysql_login;
	global $conf_mysql_pass;
	global $conf_mysql_db;

	$ressource_id = mysql_connect("$conf_mysql_host", "$conf_mysql_login", "$conf_mysql_pass");
	if($ressource_id == false)	return false;
	return @mysql_select_db($conf_mysql_db)or die("Cannot select db: $conf_mysql_db");
}

//TODO: remove above, and use normal autoSQLconfig.php values

if (!connect2base())
{
	echo "Could not connect to DB!";
	exit (1);
} else {
	
	$last_loop = 0;
	// loop until we want to shutdown... 
	$shutdown = false;
	while (!$shutdown)
	{
		if ($last_loop > 0)
		{
			$time_elapsed_since_last_run = time() - $last_loop;
			echo "Time since last run $time_elapsed_since_last_run seconds...\n";
			
			// if the time elapsed is less than 10 minutes, sleep until it is
			if ($time_elapsed_since_last_run < $conf_time_delay_in_seconds)
			{
				echo "Sleeping for " . ($conf_time_delay_in_seconds - $time_elapsed_since_last_run) . " seconds...\n";
				sleep ($conf_time_delay_in_seconds - $time_elapsed_since_last_run);
			}
		}
		$last_loop = time();
		
		$query = "SELECT * FROM vps;";
		$result = mysql_query($query)or die("Cannot query $query !!!".mysql_error());
		$num_rows = mysql_num_rows($result);
		for ($i = 0; $i < $num_rows; $i++)
		{
			$row = mysql_fetch_array($result);
			// print_r ($row);
			$vps_server = $row['vps_server_hostname'];
			$vps_name = "xen" . $row['vps_xen_name'];
			$cpu_usage = 0;
			$io_usage_disk = 0;
			$io_usage_swap = 0;
			$network_usage_in = 0;
			$network_usage_out = 0;
			
			echo "Fetching stats from $vps_server for $vps_name...\n";
			$soap_client = connectToVPSServer($vps_server);
			$r = $soap_client->call("getCPUUsage",array("vpsname" => $vps_name),"","","");
			$err = $soap_client->getError();
			if ($err) {
			  echo $err;
			} else {
				echo "Soap client returned: $r\n";
				$cpu_usage = $r;
			}
			
			
			$r = $soap_client->call("getNetworkUsage",array("vpsname" => $vps_name),"","","");
			$err = $soap_client->getError();
			if ($err) {
			  echo $err;
			} else {
				echo "Soap client returned: $r\n";
				$network_usage_array=split(",", $r);
				$network_usage_in=$network_usage_array[0];
				$network_usage_out=$network_usage_array[1];
			}
			
			$r = $soap_client->call("getIOUsage",array("vpsname" => $vps_name),"","","");
			$err = $soap_client->getError();
			if ($err) {
			  echo $err;
			} else {
				echo "Soap client returned: $r\n";
				if ($r != "NOTOK")
				{
					$io_usage_disk = $r[0];
					$io_usage_swap= $r[1];
				}
			}
			
			echo "Stats are as follows:\n";
			echo " - CPU Usage: $cpu_usage\n";
			echo " - Network Incoming: $network_usage_in\n";
			echo " - Network Outgoing: $network_usage_out\n";
			echo " - Disk IO Usage: $io_usage_disk\n";
			echo " - Swap IO Usage: $io_usage_swap\n";			
			
			// get the previous values in the table for calculation purposes
			$current_month = date("m");
			$current_year = date("Y");
			
			$query = "SELECT * from vps_stats where vps_server_hostname='$vps_server' and vps_xen_name='$vps_name' and month='$current_month' and year='$current_year';";
			$result = mysql_query($query)or print("Cannot query $query !!!".mysql_error());
			$num_rows = mysql_num_rows($result);
			
			// we need to insert a row here if it doesn't exist yet
			if ($num_rows == 0)
			{
					$query = "INSERT INTO vps_stats (vps_server_hostname,vps_xen_name,month,year) values ('$vps_server','$vps_name','$current_month','$current_year');";
					$result = mysql_query($query)or print("Cannot query $query !!!".mysql_error());
			} else if ($num_rows == 1) {
				$row = mysql_fetch_array($result);
				$vps_last_run = $row['last_run'];
				$vps_last_cpu = $row['cputime_last'];
				$vps_last_network_in = $row['network_in_last'];
				$vps_last_network_out = $row['network_out_last'];
				$vps_last_diskio = $row['diskio_last'];
				$vps_last_swapio = $row['swapio_last'];
			} else {
				echo "Corrupt vps_stats table, please check...\n";
			}
				
			// if we have actually run before, then we can calculate stats since last run
			if (isset($vps_last_run))
			{
				echo "We have a last run...\n";
				// ignore anything that has a last run of zero		
				$current_time = time();
				$time_now = $current_time;		
				echo "Time now $time_now\n";
				echo "Time last run $vps_last_run\n";
								
				$time_diff = $time_now - $vps_last_run;	
				
				// first calculate $cpu_diff
				$cpu_diff = 0;
				if ($vps_last_cpu > 0)
				{
					$cpu_diff = $cpu_usage - $vps_last_cpu;
				}
				echo "Used $cpu_diff CPU time over $time_diff seconds...\n";
				
				echo "CPU% " . ($cpu_diff / $time_diff) . "\n";
				
				// then calculate network bytes change
				$network_in_diff = 0;
				if ($vps_last_network_in > 0)
				{
					$network_in_diff = $network_usage_in - $vps_last_network_in;
				}
				
				echo "Used $network_in_diff network incoming over $time_diff seconds...\n";
				
				$network_out_diff = 0;
				if ($vps_last_network_out > 0)
				{
					$network_out_diff = $network_usage_out - $vps_last_network_out;
				}
				
				echo "Used $network_out_diff network outgoing over $time_diff seconds...\n";
				
				// then calculate disk IO and swap IO
				$diskio_diff = 0;
				if ($vps_last_diskio > 0)
				{
					$diskio_diff = $io_usage_disk - $vps_last_diskio;
				}
				
				echo "Used $diskio_diff disk IO over $time_diff seconds...\n";
				$swapio_diff = 0;
				if ($vps_last_swapio > 0)
				{
					$swapio_diff = $io_usage_swap - $vps_last_swapio;
				}
				
				echo "Used $swapio_diff swap IO over $time_diff seconds...\n";
				
				// finally populate the details into the table
				$query = "UPDATE vps_stats set last_run='$current_time',cputime_last='$cpu_usage',cpu_usage=cpu_usage + '$cpu_diff',network_in_last='$network_usage_in',network_out_last='$network_usage_out',";
				$query .= "network_in_count=network_in_count+'$network_in_diff',network_out_count=network_out_count+'$network_out_diff',diskio_last='$io_usage_disk',swapio_last='$io_usage_swap',diskio_count=diskio_count + '$diskio_diff',swapio_count=swapio_count + '$swapio_diff'";
				$query .= " where vps_server_hostname='$vps_server' and vps_xen_name='$vps_name' and month='$current_month' and year='$current_year';";
				$result = mysql_query($query)or print("Cannot query $query !!!".mysql_error());
			} else {
				echo "We don't have a last run...\n";
				// otherwise we just need to zero out the count columns, and have the last columns updated
				$query = "UPDATE vps_stats set last_run='$current_time',cputime_last='$cpu_usage',cpu_usage='0',network_in_last='$network_usage_in',network_out_last='$network_usage_out',";
				$query .= "network_in_count='0',network_out_count='0',diskio_last='$io_usage_disk',swapio_last='$io_usage_swap',diskio_count='0',swapio_count='0'";
				$query .= " where vps_server_hostname='$vps_server' and vps_xen_name='$vps_name' and month='$current_month' and year='$current_year';";
				$result = mysql_query($query)or print("Cannot query $query !!!".mysql_error());
			}
			
		}
	
	}
}
	

?> 
