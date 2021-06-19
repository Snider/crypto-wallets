FROM lthn/build:base-ubuntu-20-04
COPY --from=lthn/sdk-shell /home/lthn/ /home/lthn/
RUN chmod +x lthn.sh ; ln -s /home/lthn/lthn.sh /usr/bin/lthn
WORKDIR /home/lthn
COPY . .
ENTRYPOINT lthn sync