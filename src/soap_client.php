<?php

$host = "dtc.xen650202.gplhost.com";
// $host = "mirror.tusker.net";

require("nusoap.php");

$soap_client = new soapclient("https://$host:8089/");
$soap_client->setCredentials("JohnDoe", "JDsPassword");
$r = $soap_client->call("testVPSServer","","","","");
$err = $soap_client->getError();
if(!$err){
  echo "Result: ".$r;
}else{
  echo "Error: ".$err;
}


?>
