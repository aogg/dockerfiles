<?php
/** @noinspection PhpComposerExtensionStubsInspection */

echo __FILE__ . PHP_EOL;
opcache_invalidate(__FILE__, true);
opcache_compile_file(__FILE__);

//var_dump($_SERVER);

if (
    empty($_SERVER['REMOTE_ADDR'])
    || filter_var($_SERVER['REMOTE_ADDR'], FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)
) {
    echo '非法访问' . PHP_EOL;
    return;
}

$file = '/tmp/git_pull_files.log';
if (!is_file($file) || !is_readable($file)) {
    echo '文件不存在' . PHP_EOL;
    return;
}

$content = file_get_contents($file);
echo '------git更新内容-------start' . PHP_EOL;
echo $content;
echo '------git更新内容-------end' . PHP_EOL;
$arr = preg_split('/[;\r\n]+/s', $content);



foreach ($arr as $item) {
    if (strpos($item, '.php') === false) {
        continue;
    }

    if (!is_file($item) && !is_file(__DIR__ . '/' . ltrim($item, '/'))) {
        continue;
    }

    echo $item . PHP_EOL;
    var_dump(opcache_invalidate($item,  true));
    var_dump(opcache_compile_file($item));
}


