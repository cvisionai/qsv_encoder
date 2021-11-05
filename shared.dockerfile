FROM ubuntu:20.04 as qsv_builder

#Handle timezone prompt
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && \
    apt-get -y install autoconf automake build-essential libass-dev libtool \
                       pkg-config texinfo zlib1g-dev libva-dev cmake mercurial \
                       libdrm-dev libvorbis-dev libogg-dev git libx11-dev \
                       libperl-dev libpciaccess-dev libpciaccess0 \
                       xorg-dev intel-gpu-tools opencl-headers libwayland-dev \
                       xutils-dev ocl-icd-* meson ninja-build libx264-dev && \
    rm -fr /var/lib/apt/lists/*


WORKDIR /work
RUN mkdir -p vaapi
RUN mkdir -p ffmpeg_build
RUN mkdir -p ffmpeg_sources

# Build vaapi + libdrm
WORKDIR /work/vaapi
RUN git clone https://anongit.freedesktop.org/git/mesa/drm.git libdrm
WORKDIR /work/vaapi/libdrm
RUN meson --prefix=/opt/qsv builddir
RUN ninja -C builddir/ install

WORKDIR /work/vaapi
RUN git clone https://github.com/intel/libva
WORKDIR /work/vaapi/libva
RUN ./autogen.sh --prefix=/opt/qsv
RUN make -j$(nproc) && make -j$(nproc) install

# Build gmmlib
WORKDIR /work/vaapi/workspace
RUN git clone https://github.com/intel/gmmlib
WORKDIR /work/vaapi/workspace/build
RUN cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/qsv ../gmmlib
RUN make -j$(nproc) && make -j$(nproc) install

RUN echo "/opt/qsv/lib" > /etc/ld.so.conf.d/qsv.conf
RUN ldconfig -vvvv
ENV PKG_CONFIG_PATH=/opt/qsv/lib/pkgconfig

# Intel media driver
WORKDIR /work/vaapi/workspace
RUN git clone https://github.com/intel/media-driver
WORKDIR /work/vaapi/workspace/media-driver
RUN git submodule update --init
WORKDIR /work/vaapi/workspace/build_media
RUN cmake ../media-driver \
    -DMEDIA_VERSION="2.0.0" \
    -DBS_DIR_GMMLIB=$PWD/../gmmlib/Source/GmmLib/ \
    -DBS_DIR_COMMON=$PWD/../gmmlib/Source/Common/ \
    -DBS_DIR_INC=$PWD/../gmmlib/Source/inc/ \
    -DBS_DIR_MEDIA=$PWD/../media-driver \
    -DCMAKE_INSTALL_PREFIX=/opt/qsv \
    -DINSTALL_DRIVER_SYSCONF=OFF \
    -DLIBVA_DRIVERS_PATH=/opt/qsv/lib/dri \
    -DBYPASS_MEDIA_ULT=yes
RUN make -j$(nproc)
RUN make -j$(nproc) install

# Intel VA-API driver
WORKDIR /work/vaapi
RUN git clone https://github.com/intel/intel-vaapi-driver
WORKDIR /work/vaapi/intel-vaapi-driver
RUN ./autogen.sh --prefix=/opt/qsv
RUN make -j$(nproc) && make -j$(nproc) install

WORKDIR /work/vaapi
RUN git clone https://github.com/intel/libva-utils
WORKDIR /work/vaapi/libva-utils
RUN ./autogen.sh --prefix=/opt/qsv
RUN make -j$(nprocs) && make -j$(nprocs) install

ENV PATH=/opt/qsv/bin:${PATH}

WORKDIR /work/vaapi
RUN git clone https://github.com/Intel-Media-SDK/MediaSDK msdk
WORKDIR /work/vaapi/msdk
RUN git submodule update --init

RUN apt-get update && \
    apt-get install -y libxcb-dri3-dev libxcb-present-dev libx11-xcb-dev &&\
    rm -fr /var/lib/apt/lists/*

# WARNING: This will go to /opt/intel because the cmakelists.txt is broken
WORKDIR /work/vaapi/build_msdk
RUN cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_WAYLAND=ON -DENABLE_X11_DRI3=ON -DENABLE_OPENCL=ON ../msdk
RUN make -j$(nprocs) && make -j$(nprocs) install

ENV PKG_CONFIG_PATH=/opt/intel/mediasdk/lib/pkgconfig/:${PKG_CONFIG_PATH}
RUN echo "/opt/intel/lib" >> /etc/ld.so.conf.d/qsv.conf
RUN echo "/opt/intel/plugins" >> /etc/ld.so.conf.d/qsv.conf
RUN ldconfig -vvvv

RUN apt-get update && \
    apt-get install -y nasm &&\
    rm -fr /var/lib/apt/lists/
    
WORKDIR /work
RUN git clone https://github.com/FFmpeg/FFmpeg -b master ffmpeg
WORKDIR /work/ffmpeg
RUN ./configure --prefix=/opt/qsv --enable-libmfx --enable-libfreetype --enable-libx264 --enable-gpl --enable-shared
RUN make -j$(nprocs) && make -j$(nprocs) install

###################################
## Second Stage (execution image)
###################################
FROM ubuntu:20.04 as qsv_encoder
COPY --from=qsv_builder /opt /opt

ENV PATH=/opt/qsv/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/qsv/lib:/opt/qsv/lib/x86_64-linux-gnu/:/opt/intel/mediasdk/lib
RUN apt-get update && \
    apt-get -y install libx11-6 libxcb1 libpciaccess0 libass9 \
                       libwayland-client0 libwayland-cursor0 \
                       libxext6 libxfixes3 libxcb-xfixes0 libxcb-shape0 \
                       libxv1 libx264-155 && \
    rm -fr /var/lib/apt/lists/*

COPY files/test.sh /test/test.sh
