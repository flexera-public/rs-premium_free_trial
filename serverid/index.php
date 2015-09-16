<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<?php 

# Copyright 2010 RightScale, Inc. All rights reserved. 

$ip_addr=$_SERVER['SERVER_ADDR'];
$hostname=$_SERVER['SERVER_NAME'];

?>

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

<h3>
PHP server
</h3>
ip=<?php echo $ip_addr ?>; <br/>
hostname=<?php echo $hostname ?>; <br/>
<br/>
REMOTE_ADDR=<?php echo $_SERVER['REMOTE_ADDR'] ?>; <br/>
HTTP_X_FORWARDED_FOR=<?php echo $_SERVER['HTTP_X_FORWARDED_FOR'] ?>; <br/>

</div>
</div>

</body>
</html>
