# -*- coding: utf-8 -*-
# Copyright (C) 2019-2020, MACREL Authors
# vim: set ts=4 sts=4 sw=4 expandtab smartindent:
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

import setuptools
import os

exec(compile(open('macrel/macrel_version.py').read(),
             'macrel/macrel_version.py', 'exec'))

try:
    long_description = open('README.md', encoding='utf-8').read()
except:
    long_description = open('README.md').read()


package_dir = {
        'macrel': 'macrel/',
    }
package_data = {
        'macrel': ['data/*'],
        }

packages = setuptools.find_packages()

classifiers = [
'Development Status :: 4 - Beta',
'Intended Audience :: Science/Research',
'Programming Language :: Python',
'Programming Language :: Python :: 2',
'Programming Language :: Python :: 2.7',
'Programming Language :: Python :: 3',
'Programming Language :: Python :: 3.6',
'Programming Language :: Python :: 3.7',
'Programming Language :: R',
'Operating System :: OS Independent',
'License :: OSI Approved :: MIT License',
]

setuptools.setup(name = 'macrel',
      version = __version__,
      description = 'MACREL',
      long_description = long_description,
      long_description_content_type = 'text/markdown',
      author = 'Celio Dias Santos-Junior and Luis Pedro Coelho',
      author_email = 'luispedro@big-data-biology.org',
      license = 'MIT',
      platforms = ['Any'],
      classifiers = classifiers,
      packages = packages,
      package_dir = package_dir,
      package_data = package_data,
      zip_safe = False, # We want the RDS files to be installed as files
      entry_points={
          'console_scripts': [
              'macrel= macrel.main:main',
          ],
      },
      test_suite = 'nose.collector',
      )
