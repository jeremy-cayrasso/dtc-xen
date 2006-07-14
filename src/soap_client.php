<?php

require("nusoap.php");

$soap_client = new soapclient("https://dtc.xen650202.gplhost.com:8089/");

$r = $soap_client->call("testVPSServer");
$err = $soap_client->getError();
if(!$err){
  echo "Result: ".$r;
}else{
  echo "Error: ".$err;
}


?>