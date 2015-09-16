<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
   
<!-- # Copyright 2010 RightScale, Inc. All rights reserved.  -->

   
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <title>RightScale Unified Test App</title>
    <link rel="stylesheet" type="text/css" href="../style.css" />  
</head>

<body>

<div id="header">
<div id="logo"><img src="../images/logo.png" /></div>
</div>

<div class="code_container">
<div class="code">

<H1><center>A New Database Connection Test</center></H1>

<?php

include '../config/db.php';

mysql_connect($hostname_DB,$username_DB,$password_DB);
@mysql_select_db($database_DB) or die( "Unable to select database");
$query="SELECT * FROM app_test";
$result=mysql_query($query);

$num=mysql_numrows($result);

mysql_close();

echo "<b><center> Data Dump from Database, $database_DB</center></b><br><br>";

$i=0;
while ($i < $num) {

$name=mysql_result($result,$i,"name");
$value=mysql_result($result,$i,"value");


echo "<b><center>$name - $value</center></b><br><hr><br>";

$i++;
}

?>

</div>
</div>

</body>
</html>
