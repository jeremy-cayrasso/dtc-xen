<?php

$port = 8089;
// $host = "localhost";
$host = "dtc.xen650202.gplhost.com";
// $host = "mirror.tusker.net";
// $host = "node6502.gplhost.com";

require("nusoap.php");

$soap_client = new soapclient("https://$host:$port/");
$soap_client->setCredentials("dtc-xen", "test");
$r = $soap_client->call("listStartedVPS","","","","");

$err = $soap_client->getError();
if(!$err){
  echo "Result: ".print_r($r);
}else{
  echo "Error: ".$err;
}

$r = $soap_client->call("startVPS",array("vpsname" => "xen13"),"","","");
$err = $soap_client->getError();
if(!$err){
  echo "Result: ".print_r($r);
}else{
  echo "Error: ".$err;
}


?>
