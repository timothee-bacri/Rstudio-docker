#!/usr/bin/env bash
USERS="dw356 ik354 mh1176 trfb201 jm622 mcm216 hc629 cassandrabird jmose batistahpedro mariomartinez"
USER_IDS="502 505 503 507 504 506 508 509 510 511 512"
DEFAULT_PASSWORD="orchid"
USERS_ARRAY=($USERS)
USER_IDS_ARRAY=($USER_IDS)

# Create new users if they are not present on the container
for i in "${!USERS_ARRAY[@]}"; do
  user="${USERS_ARRAY[i]}"
  user_id="${USER_IDS_ARRAY[i]}"
  # Add user only if not already available
  if ! id "${user}" &>/dev/null; then
    # Create the user
    useradd --create-home --no-user-group --gid rstudio-users --uid "${user_id}" --shell /bin/bash --comment "" "${user}" 
    # Set the user with the default password
    usermod -p "${DEFAULT_PASSWORD}" "${user}"
  fi
done

# Let users install packages, update package list, search
# https://unix.stackexchange.com/questions/690749/how-to-enable-sudo-privileges-for-user-group-to-apt-get-install-anything
SUDOERS_FILE="/etc/sudoers.d/group-rstudio-users"
mkdir -p /etc/sudoers.d
echo "User_Alias MYUSERS = ${USERS// /,}" > "${SUDOERS_FILE}"
echo "Cmnd_Alias INSTALL = /usr/bin/apt-get install *, /usr/bin/apt install *" >> "${SUDOERS_FILE}"
echo "Cmnd_Alias UPDATE = /usr/bin/apt-get update, /usr/bin/apt update" >> "${SUDOERS_FILE}"
echo "Cmnd_Alias SEARCH = /usr/bin/apt-get search *, /usr/bin/apt search *" >> "${SUDOERS_FILE}"
echo "MYUSERS ALL = INSTALL, UPDATE, SEARCH" >> "${SUDOERS_FILE}"
