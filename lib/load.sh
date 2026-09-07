# shellcheck shell=bash
# Load all phpdev libraries (PHPDEV_ROOT must be set or derived)

_phpdev_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$_phpdev_here/common.sh"
# shellcheck source=lib/install/system.sh
source "$_phpdev_here/install/system.sh"
# shellcheck source=lib/install/web.sh
source "$_phpdev_here/install/web.sh"
# shellcheck source=lib/install/php.sh
source "$_phpdev_here/install/php.sh"
# shellcheck source=lib/install/database.sh
source "$_phpdev_here/install/database.sh"
# shellcheck source=lib/install/tools.sh
source "$_phpdev_here/install/tools.sh"
# shellcheck source=lib/install/apps.sh
source "$_phpdev_here/install/apps.sh"
# shellcheck source=lib/install/scripts.sh
source "$_phpdev_here/install/scripts.sh"
# shellcheck source=lib/util.sh
source "$_phpdev_here/util.sh"
# shellcheck source=lib/lang.sh
source "$_phpdev_here/lang.sh"
# shellcheck source=lib/db.sh
source "$_phpdev_here/db.sh"
# shellcheck source=lib/cli.sh
source "$_phpdev_here/cli.sh"
# shellcheck source=lib/profiles.sh
source "$_phpdev_here/profiles.sh"
