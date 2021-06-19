FROM lthn/sdk-shell

WORKDIR /home/lthn/wallets

COPY . .

RUN chmod +x lthn.sh ; ln -s /home/lthn/wallets/lthn.sh /usr/bin/lthn

ENTRYPOINT lthn help