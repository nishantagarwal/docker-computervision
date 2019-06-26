FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# install linux packages
COPY linux/ubuntu18/packages.txt /install/
WORKDIR /install
RUN apt-get -qq update && xargs -a packages.txt apt-get -qq install -y --no-install-recommends && apt-get clean

# Set python
RUN cd /usr/local/bin && ln -s /usr/bin/python3 python && ln -s /usr/bin/pip3 pip

# Install python packages
COPY python36/requirements.txt /install/
RUN pip install -q -r requirements.txt
        
# Download OSS projects
RUN wget -q https://github.com/cocodataset/cocoapi/archive/master.zip -O cocoapi.zip && \
    wget -q https://github.com/google/protobuf/releases/download/v3.0.0/protoc-3.0.0-linux-x86_64.zip -O protobuf.zip && \
    wget -q https://github.com/tensorflow/models/archive/59f7e80ac8ad54913663a4b63ddf5a3db3689648.zip -O tensorflow-models.zip
RUN unzip cocoapi.zip && unzip protobuf.zip -d ./protobuf && unzip tensorflow-models.zip -d ./tensorflow-models
RUN mkdir /oss

# Install cocoapi
RUN mv /install/cocoapi-master /oss/cocoapi
WORKDIR /oss/cocoapi/PythonAPI
RUN python setup.py install

# Install tensorflow object detection
RUN mv /install/tensorflow-models/models-59f7e80ac8ad54913663a4b63ddf5a3db3689648 /oss/tf-models && mv /install/protobuf /oss
WORKDIR /oss/tf-models/research
RUN /oss/protobuf/bin/protoc ./object_detection/protos/*.proto --python_out=.
RUN python setup.py install

# Remove temp and cache folders
RUN rm -rf /var/lib/apt/lists/* && rm -rf /var/cache/apt/* && rm -rf /root/.cache/* && rm -rf /install && apt-get clean
