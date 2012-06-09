#-*- coding: utf-8 -*-
#
# Copyright (c) 2012 Shunsuke Ito
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

# gem require
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'pp'
require 'uuidtools'
require 'erb'
require 'redcarpet'
require 'digest/md5'
require 'open-uri'
require 'mime/types'
require 'RedCloth'

require "md2epub/version"
require "md2epub/image_fetcher"
require "md2epub/config"
require "md2epub/markdown2epub"
