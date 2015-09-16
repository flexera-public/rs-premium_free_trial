<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
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
MD5 Test
</h3>
<?php
function generateRandomString($length = 10) {
  return substr(str_shuffle("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABC"), 0, $length);
}

$loops=1000;
if (!isset($_GET['loops'])) {
  echo "GET parameter 'loops' not set, using ".$loops."<br/><br/>";
} else {
  $loops=$_GET['loops'];
  echo "Looping ".$loops." times<br/><br/>";
}

for($i = 1; $i <= $loops; $i++) {
  $randomString = generateRandomString(100);
  echo "String($i) = ".$randomString.", MD5 = ".md5($randomString)."<br/>";
}
?>

</div>
</div>

</body>
</html>

