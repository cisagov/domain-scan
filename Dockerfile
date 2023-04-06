# VERSION 0.3.0

FROM ubuntu:20.04
MAINTAINER Shane Frasier <jeremy.frasier@trio.dhs.gov>

###
# Dependencies
###
ENV DEBIAN_FRONTEND=noninteractive

RUN \
    apt-get update \
        --quiet --quiet \
    && apt-get install \
        --quiet --quiet \
        --yes \
        --no-install-recommends \
        --no-install-suggests \
      apt-utils \
      autoconf \
      automake \
      bison \
      build-essential \
      curl \
      gawk \
      git \
      libc6-dev \
      libffi-dev \
      libfontconfig1 \
      libgdbm-dev \
      libncurses5-dev \
      libreadline-dev \
      libsqlite3-dev \
      libssl-dev \
      libssl-doc \
      libtool \
      libxml2-dev \
      libxslt1-dev \
      libyaml-dev \
      make \
      pkg-config \
      sqlite3 \
      sudo \
      unzip \
      wget \
      zlib1g-dev \
      # Additional dependencies for python-build
      libbz2-dev \
      libncursesw5-dev \
      llvm \
      # Additional dependencies for third-parties scanner
      nodejs \
      npm \
      # Additional dependencies for a11y scanner
      net-tools \
      # Chrome dependencies
      fonts-liberation \
      libappindicator3-1 \
      libasound2 \
      libatk-bridge2.0-0 \
      libdrm2 \
      libgbm1 \
      libgtk-3-0 \
      libnspr4 \
      libnss3 \
      libu2f-udev \
      libvulkan1 \
      libxss1 \
      libxtst6 \
      lsb-release \
      xdg-utils

RUN apt-get install --quiet --quiet --yes locales && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

###
# Google Chrome
###
RUN wget --quiet https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && dpkg --install google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb
# The third-parties scanner looks for an executable called chrome
RUN ln --symbolic /usr/bin/google-chrome-stable /usr/bin/chrome

###
## Python
###
ENV PYENV_RELEASE=2.3.17
ENV PYENV_PYTHON_VERSION=3.7.16
ENV PYENV_ROOT=/opt/pyenv
ENV PYENV_REPO=https://github.com/pyenv/pyenv

RUN wget ${PYENV_REPO}/archive/v${PYENV_RELEASE}.zip \
      --no-verbose \
    && unzip v$PYENV_RELEASE.zip -d $PYENV_ROOT \
    && mv $PYENV_ROOT/pyenv-$PYENV_RELEASE/* $PYENV_ROOT/ \
    && rm --recursive $PYENV_ROOT/pyenv-$PYENV_RELEASE

#
# Uncomment these lines if you just want to install python...
#
ENV PATH $PYENV_ROOT/bin:$PYENV_ROOT/versions/${PYENV_PYTHON_VERSION}/bin:$PATH
RUN echo 'eval "$(pyenv init -)"' >> /etc/profile \
    && eval "$(pyenv init -)" \
    && pyenv install $PYENV_PYTHON_VERSION \
    && pyenv local ${PYENV_PYTHON_VERSION}

#
# ...uncomment these lines if you want to also debug python code in GDB
#
# ENV PATH $PYENV_ROOT/bin:$PYENV_ROOT/versions/${PYENV_PYTHON_VERSION}-debug/bin:$PATH
# RUN echo 'eval "$(pyenv init -)"' >> /etc/profile \
#     && eval "$(pyenv init -)" \
#     && pyenv install --debug --keep $PYENV_PYTHON_VERSION \
#     && pyenv local ${PYENV_PYTHON_VERSION}-debug
# RUN ln --symbolic /opt/pyenv/sources/${PYENV_PYTHON_VERSION}-debug/Python-${PYENV_PYTHON_VERSION}/python-gdb.py \
#     /opt/pyenv/versions/${PYENV_PYTHON_VERSION}-debug/bin/python3.6-gdb.py \
#     && ln --symbolic /opt/pyenv/sources/${PYENV_PYTHON_VERSION}-debug/Python-${PYENV_PYTHON_VERSION}/python-gdb.py \
#     /opt/pyenv/versions/${PYENV_PYTHON_VERSION}-debug/bin/python3-gdb.py \
#     && ln --symbolic /opt/pyenv/sources/${PYENV_PYTHON_VERSION}-debug/Python-${PYENV_PYTHON_VERSION}/python-gdb.py \
#     /opt/pyenv/versions/${PYENV_PYTHON_VERSION}-debug/bin/python-gdb.py
# RUN apt-get --quiet --quiet --yes --no-install-recommends --no-install-suggests install gdb
# RUN echo add-auto-load-safe-path \
#     /opt/pyenv/sources/${PYENV_PYTHON_VERSION}-debug/Python-${PYENV_PYTHON_VERSION}/ \
#     >> etc/gdb/gdbinit

###
# Update pip and setuptools to the latest versions
###
RUN pip install --upgrade pip setuptools wheel

###
# Node
###
RUN curl --fail --shell --stdin --location https://deb.nodesource.com/setup_14.x | sudo --preserve-env bash
RUN apt-get install --quiet --quiet --yes nodejs

###
## pa11y
###

RUN wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 \
    && tar xvjf phantomjs-2.1.1-linux-x86_64.tar.bz2 --directory /usr/local/share/ \
    && ln --symbolic /usr/local/share/phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin/
RUN npm install --global pa11y@4.13.2 --ignore-scripts

###
## third_parties
###

RUN npm install puppeteer

###
# Create unprivileged User
###
ENV SCANNER_HOME /home/scanner
RUN mkdir $SCANNER_HOME \
    && groupadd --system scanner \
    && useradd --system --comment "Scanner user" --gid scanner scanner \
    && chown --recursive scanner:scanner ${SCANNER_HOME}

###
# Prepare to Run
###
WORKDIR $SCANNER_HOME

# Volume mount for use with the 'data' option.
VOLUME /data

COPY . $SCANNER_HOME

###
# domain-scan
###
RUN pip install --upgrade \
    --requirement requirements.txt \
    --requirement requirements-gatherers.txt \
    --requirement requirements-scanners.txt

# Clean up aptitude stuff we no longer need
RUN apt-get clean && rm --recursive --force /var/lib/apt/lists/*

ENTRYPOINT ["./scan_wrap.sh"]
