curl --location --request POST "http://localhost:8080/" ^
More? --header "Accept: */*" ^
More? --header "Host: localhost:8080" ^
More? --header "Connection: keep-alive" ^
More? --data-urlencode "cmd=echo 1 && ping -n 6 127.0.0.1 && echo 2"