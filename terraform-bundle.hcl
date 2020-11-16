# Copyright (c) 2017 SAP SE or an SAP affiliate company. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  version = "TF_VERSION"
}

providers {
  aws         = ["2.68.0"]
  azurerm     = ["2.36.0"]
  google      = ["3.27.0"]
  google-beta = ["3.27.0"]
  openstack   = ["1.28.0"]
  alicloud    = ["1.103.0"]
  packet      = ["2.3.0"]
  template    = ["2.1.2"]
  null        = ["2.1.2"]
}
