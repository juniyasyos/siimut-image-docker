<?php
// Simple Hello World with System Information
echo "<h1>Hello World!</h1>";
echo "<h2>System Information</h2>";

echo "<h3>Server Information:</h3>";
echo "<ul>";
echo "<li><strong>Server Name:</strong> " . $_SERVER['SERVER_NAME'] . "</li>";
echo "<li><strong>Server Software:</strong> " . $_SERVER['SERVER_SOFTWARE'] . "</li>";
echo "<li><strong>PHP Version:</strong> " . phpversion() . "</li>";
echo "<li><strong>Server Time:</strong> " . date('Y-m-d H:i:s') . "</li>";
echo "<li><strong>Server OS:</strong> " . php_uname('s') . " " . php_uname('r') . "</li>";
echo "<li><strong>Server Architecture:</strong> " . php_uname('m') . "</li>";
echo "</ul>";

echo "<h3>Request Information:</h3>";
echo "<ul>";
echo "<li><strong>Request Method:</strong> " . $_SERVER['REQUEST_METHOD'] . "</li>";
echo "<li><strong>Request URI:</strong> " . $_SERVER['REQUEST_URI'] . "</li>";
echo "<li><strong>User Agent:</strong> " . $_SERVER['HTTP_USER_AGENT'] . "</li>";
echo "<li><strong>Remote IP:</strong> " . $_SERVER['REMOTE_ADDR'] . "</li>";
echo "</ul>";

echo "<h3>PHP Configuration:</h3>";
echo "<ul>";
echo "<li><strong>Memory Limit:</strong> " . ini_get('memory_limit') . "</li>";
echo "<li><strong>Max Execution Time:</strong> " . ini_get('max_execution_time') . " seconds</li>";
echo "<li><strong>Upload Max Filesize:</strong> " . ini_get('upload_max_filesize') . "</li>";
echo "<li><strong>Post Max Size:</strong> " . ini_get('post_max_size') . "</li>";
echo "</ul>";

echo "<hr>";
echo "<p><em>Generated on: " . date('Y-m-d H:i:s') . "</em></p>";
?>