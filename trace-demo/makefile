build-gateway-linux:
	GOOS=linux GOARCH=amd64 go build  -o build/gateway ./api-gateway
build-gateway-mac:
	GOOS=darwin GOARCH=amd64 go build -o build/gateway-mac ./api-gateway

build-back-service-linux:
	GOOS=linux GOARCH=amd64 go build -o build/backservice ./backend-service
build-back-service-mac:
	GOOS=darwin GOARCH=amd64 go build -o build/backservice-mac ./backend-service