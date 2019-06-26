FROM ubuntu:18.04

# Set up cuda 9.0

RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends gnupg2 curl ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1704/x86_64 /" >> /etc/apt/sources.list.d/cuda.list && \
    echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64 /" >> /etc/apt/sources.list.d/nvidia-ml.list && \
    apt-get purge --autoremove -y curl

ENV CUDA_VERSION 9.0.176
ENV CUDA_PKG_VERSION 9-0=$CUDA_VERSION-1

RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
        cuda-cudart-$CUDA_PKG_VERSION && \
    ln -s cuda-9.0 /usr/local/cuda

RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

ENV PATH /usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA "cuda>=9.0"
ENV NCCL_VERSION 2.3.7

RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
        cuda-libraries-$CUDA_PKG_VERSION \
        cuda-cublas-9-0=9.0.176.4-1 \
        libnccl2=$NCCL_VERSION-1+cuda9.0 && \
    apt-mark hold libnccl2

RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
        cuda-libraries-dev-$CUDA_PKG_VERSION \
        cuda-nvml-dev-$CUDA_PKG_VERSION \
        cuda-minimal-build-$CUDA_PKG_VERSION \
        cuda-command-line-tools-$CUDA_PKG_VERSION \
        cuda-core-9-0=9.0.176.3-1 \
        cuda-cublas-dev-9-0=9.0.176.4-1 \
        libnccl-dev=$NCCL_VERSION-1+cuda9.0

ENV LIBRARY_PATH /usr/local/cuda/lib64/stubs
ENV CUDNN_VERSION 7.4.1.5
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
            libcudnn7=$CUDNN_VERSION-1+cuda9.0 \
            libcudnn7-dev=$CUDNN_VERSION-1+cuda9.0 && \
    apt-mark hold libcudnn7

ENV DEBIAN_FRONTEND=noninteractive

# install linux packages
COPY linux/ubuntu18/packages.txt /install/
WORKDIR /install
RUN apt-get -qq update \
    && xargs -a packages.txt apt-get -qq install -y --no-install-recommends

# Set python
RUN cd /usr/local/bin && ln -s /usr/bin/python3 python && ln -s /usr/bin/pip3 pip

# Set CUDA related library path
ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Install python packages
COPY python36/requirements.txt /install/
COPY python36/requirements-gpu.txt /install/
RUN pip install -q -r requirements.txt
RUN pip install -q -r requirements-gpu.txt
        
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
