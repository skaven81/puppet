validate_multi
==============

  Validate that the first argument given can pass validation of at least one
  other validator from the puppetlabs/stdlib library. The first argument is
  the data that needs validation. Each argument following should be the data
  type suffix from a validator function. The suffix should be in the form of
  a string. The passed data will then be validated against each validation
  function listed.

Examples
--------

  The following validations will pass:

      validate_multi("I am a string",'string','array')
      validate_multi(true,'hash','bool')

  The following validations will not:

      validate_multi(false,'string','array')
      validate_multi('I am a string','hash','array')

License
-------
   Copyright 2013 Thomas Linkin <tom@puppetlabs.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

Contact
-------

ME!  <tom@puppetlabs.com>

Support
-------

Please log tickets and issues at our [Projects site](https://github.com/trlinkin/puppet-validate_multi)
