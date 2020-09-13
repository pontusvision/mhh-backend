FROM doctrine/nodejs-aws-cli
RUN sudo mkdir /work
COPY . /work/
WORKDIR /work
RUN sudo chmod 777 -R /work
ENTRYPOINT /work/setup.sh
