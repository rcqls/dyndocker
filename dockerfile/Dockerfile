FROM rcqls/dyndocker-root:latest

MAINTAINER "Cqls Team"


# install things globally, for great justice
ENV GEM_HOME /usr/local/bundle
ENV PATH $GEM_HOME/bin:$PATH
RUN gem install bundler \
	&& bundle config --global path "$GEM_HOME" \
	&& bundle config --global bin "$GEM_HOME/bin"

# don't create ".bundle" in all our apps
ENV BUNDLE_APP_CONFIG $GEM_HOME

## Dyndoc

RUN gem install rake configliere ultraviolet

RUN mkdir -p /tmp/dyndoc

WORKDIR /tmp/dyndoc

RUN git clone https://github.com/rcqls/R4rb.git 

WORKDIR R4rb

RUN rake docker

WORKDIR /tmp/dyndoc

RUN git clone https://github.com/rcqls/dyndoc-ruby-core.git 

WORKDIR dyndoc-ruby-core

RUN rake docker

WORKDIR /tmp/dyndoc

RUN git clone https://github.com/rcqls/dyndoc-ruby-doc.git 

WORKDIR dyndoc-ruby-doc

RUN rake docker

WORKDIR /tmp/dyndoc

RUN git clone https://github.com/rcqls/rb4R.git && R CMD INSTALL rb4R


## Init dyndoc home
RUN mkdir -p /dyndoc && echo "/dyndoc" > $HOME/.dyndoc_home

WORKDIR /tmp/dyndoc

RUN git clone https://github.com/rcqls/dyndoc-ruby-install.git && cp -r ./dyndoc-ruby-install/dyndoc_basic_root_structure/* /dyndoc

RUN rm -fr /tmp/dyndoc

RUN ln -s /dyndoc/bin/dyndoc-compile.rb /usr/local/bin/dyn \
	&& ln -s /dyndoc/bin/dyndoc-package.rb /usr/local/bin/dpm \
	&& ln -s /dyndoc/bin/dyndoc-server-simple.rb /usr/local/bin/dyn-srv

## mountpoints are for
RUN mkdir -p /dyndoc-library

VOLUME /dyndoc-library

## dyndoc: 	/dyndoc-library/dyndoc
RUN echo "/dyndoc-library/dyndoc" > /dyndoc/etc/dyndoc_library_path
ENV DYNDOC_LIBRARY /dyndoc-library/dyndoc

## R packages

RUN Rscript -e 'install.packages("base64")'


RUN gem install rake filewatcher

RUN mkdir -p /tmp/dyntask

WORKDIR /tmp/dyntask

RUN git clone https://github.com/rcqls/dyntask-ruby.git 

WORKDIR /tmp/dyntask/dyntask-ruby

RUN rake docker

RUN rm -fr /tmp/dyntask



RUN dyntask-init default /dyndoc-proj:dyn,pandoc



RUN echo 'dyntask-server default'  >> $HOME/.profile



## ruby:	/dyndoc-library/ruby
ENV PATH /dyndoc-library/ruby/bin:$PATH
ENV GEM_PATH /dyndoc-library/ruby:$GEM_HOME
## Last change for .gemrc to make "gem (un)install <package>" persistant  
RUN echo "gem: --no-rdoc --no-ri -i /dyndoc-library/ruby" > ~/.gemrc

## the dyndoc projects folder

RUN mkdir -p /dyndoc-proj

VOLUME /dyndoc-proj

WORKDIR /dyndoc-proj


## Port exposed by dyn-srv

EXPOSE 7777

## the server to expose
RUN echo '#!/bin/bash' > /usr/local/bin/dyndoc_and_dyntask.sh

RUN echo '/usr/local/bundle/bin/dyntask-server default&' >> /usr/local/bin/dyndoc_and_dyntask.sh

RUN echo '/usr/local/bin/dyn-srv' >> /usr/local/bin/dyndoc_and_dyntask.sh

CMD ["bash","/usr/local/bin/dyndoc_and_dyntask.sh"]


## END


