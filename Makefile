.PHONY: all run
all:
	docker build --no-cache -t snider/wallets .


run: all
	docker run -it snider/wallets bash