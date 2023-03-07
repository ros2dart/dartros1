
FROM osrf/ros:melodic-desktop

RUN echo "Install dependencies"
RUN  apt-get update && \
  apt-get install apt-transport-https wget && \
  sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -' && \
  sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_unstable.list > /etc/apt/sources.list.d/dart_unstable.list' && \
  apt-get update && \
  apt-get install dart 

RUN echo 'RUN tests'

COPY . .
RUN echo 'PATH="\$PATH:/usr/lib/dart/bin"' >> ~/.bash_profile
RUN export PATH="$PATH:/usr/lib/dart/bin"  && dart pub get
RUN export PATH="$PATH:/usr/lib/dart/bin"  && dart --disable-analytics
