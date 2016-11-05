#!/bin/sh

cat > "${DESTINATION_DIR}/kea.conf" << EOF
{
"Dhcp4":
{
  "interfaces-config": {
    "interfaces": [ "*" ]
  },

  "lease-database": {
    "type": "postgresql",
    "name": "$POSTGRES_DB",
    "host": "$POSTGRES_HOSTNAME",
    "user": "$POSTGRES_USER",
    "password": "$POSTGRES_PASSWORD",
    "connect-timeout": 5
  },

  "hosts-database": {
    "type": "postgresql",
    "name": "$POSTGRES_DB",
    "host": "$POSTGRES_HOSTNAME",
    "user": "$POSTGRES_USER",
    "password": "$POSTGRES_PASSWORD",
    "connect-timeout": 5
  },
  
  "next-server": "$TFTP_SERVER_IP",
  "option-data": [
      {
          "name": "tftp-server-name",
          "code": 66,
          "space": "dhcp4",
          "csv-format": true,
          "data": "$TFTP_SERVER_HOSTNAME"
      },
      {
        "name": "boot-file-name",
        "code": 67,
        "space": "dhcp4",
        "csv-format": true,
        "data": "pxelinux.0"
      }
  ],

  "valid-lifetime": 4000,

  "subnet4": [
  {    "subnet": "$DOCKER_NETWORK_SUBNET",
       "pools": [ { "pool": "$KEA_POOL_SUBNET" } ] },
       "id": 1
  ]
},

"Logging":
{
  "loggers": [
    {
      "name": "kea-dhcp4",
      "output_options": [
          {
            "output": "stdout"
          }
      ],
      "severity": "INFO"
    },
    {
      "name": "kea-dhcp4.bad-packets",
      "output_options": [
          {
            "output": "stderr"
          }
      ],
      "severity": "INFO"
    }
  ]
}
}
EOF