# --------------------------------------------------------
# Environment
# --------------------------------------------------------
resource "confluent_environment" "babu_gko_env" {
  display_name = local.env_name

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Schema Registry
# --------------------------------------------------------
data "confluent_schema_registry_region" "babu_gko_sr_region" {
  cloud   = "AWS"
  region  = "eu-central-1"
  package = "ESSENTIALS"
}

resource "confluent_schema_registry_cluster" "babu_gko_sr_cluster" {
  package = data.confluent_schema_registry_region.babu_gko_sr_region.package

  environment {
    id = confluent_environment.babu_gko_env.id
  }

  region {
    id = data.confluent_schema_registry_region.babu_gko_sr_region.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Cluster
# --------------------------------------------------------
resource "confluent_kafka_cluster" "babu_gko_cluster" {
  display_name = local.cluster_name
  availability = "MULTI_ZONE"
  cloud        = "AWS"
  region       = "eu-central-1"
  dedicated {
    cku = 2
  }

  environment {
    id = confluent_environment.babu_gko_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Service Accounts
# --------------------------------------------------------
resource "confluent_service_account" "source_connect_sa" {
  display_name = "source_connect_sa"
  description  = "OracleDB CDC source connect service account"
}
resource "confluent_service_account" "sr_sa" {
  display_name = "sr-sa"
  description  = "Schema Registry service account"
}
resource "confluent_service_account" "sink_connect_sa" {
  display_name = "sink_connect_sa"
  description  = "MongoDB sink connector service account"
}

# --------------------------------------------------------
# Role Bindings
# --------------------------------------------------------
resource "confluent_role_binding" "source_connect_cluster_admin" {
  principal   = "User:${confluent_service_account.source_connect_sa.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.babu_gko_cluster.rbac_crn
}

resource "confluent_role_binding" "sr_environment_admin" {
  principal   = "User:${confluent_service_account.sr_sa.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.babu_gko_env.resource_name
}

resource "confluent_role_binding" "sink_connect_cluster_admin" {
  principal   = "User:${confluent_service_account.sink_connect_sa.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.babu_gko_cluster.rbac_crn
}

# --------------------------------------------------------
# Credentials
# --------------------------------------------------------
resource "confluent_api_key" "source_connect_kafka_cluster_key" {
  display_name = "source_connect-${local.cluster_name}-key"
  description  = "OraclDB CDC source connector api key"
  owner {
    id          = confluent_service_account.source_connect_sa.id
    api_version = confluent_service_account.source_connect_sa.api_version
    kind        = confluent_service_account.source_connect_sa.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.babu_gko_cluster.id
    api_version = confluent_kafka_cluster.babu_gko_cluster.api_version
    kind        = confluent_kafka_cluster.babu_gko_cluster.kind

    environment {
      id = confluent_environment.babu_gko_env.id
    }
  }
  depends_on = [
    confluent_role_binding.source_connect_cluster_admin
  ]

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "sr_cluster_key" {
  display_name = "sr-${local.cluster_name}-key"
  description  = "Schema Registry API Key"
  owner {
    id          = confluent_service_account.sr_sa.id
    api_version = confluent_service_account.sr_sa.api_version
    kind        = confluent_service_account.sr_sa.kind
  }

  managed_resource {
    id          = confluent_schema_registry_cluster.babu_gko_sr_cluster.id
    api_version = confluent_schema_registry_cluster.babu_gko_sr_cluster.api_version
    kind        = confluent_schema_registry_cluster.babu_gko_sr_cluster.kind

    environment {
      id = confluent_environment.babu_gko_env.id
    }
  }
  depends_on = [
    confluent_role_binding.sr_environment_admin
  ]

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_api_key" "sink_connect_kafka_cluster_key" {
  display_name = "sink_connect-${local.cluster_name}-key"
  description  = local.description
  owner {
    id          = confluent_service_account.sink_connect_sa.id
    api_version = confluent_service_account.sink_connect_sa.api_version
    kind        = confluent_service_account.sink_connect_sa.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.babu_gko_cluster.id
    api_version = confluent_kafka_cluster.babu_gko_cluster.api_version
    kind        = confluent_kafka_cluster.babu_gko_cluster.kind

    environment {
      id = confluent_environment.babu_gko_env.id
    }
  }
  depends_on = [
    confluent_role_binding.sink_connect_cluster_admin
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# -------------------------------------------------------
# Confluent Topics
# -------------------------------------------------------
resource "confluent_kafka_topic" "accounts" {
  kafka_cluster {
    id = confluent_kafka_cluster.babu_gko_cluster.id
  }
  topic_name    = "ACCOUNTS"
  rest_endpoint = confluent_kafka_cluster.babu_gko_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.source_connect_kafka_cluster_key.id
    secret = confluent_api_key.source_connect_kafka_cluster_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_kafka_topic" "customers" {
  kafka_cluster {
    id = confluent_kafka_cluster.babu_gko_cluster.id
  }
  topic_name    = "CUSTOMERS"
  rest_endpoint = confluent_kafka_cluster.babu_gko_cluster.rest_endpoint
  credentials {
    key    = confluent_api_key.source_connect_kafka_cluster_key.id
    secret = confluent_api_key.source_connect_kafka_cluster_key.secret
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --------------------------------------------------------
# Oracle DB CDC Source Connector
# --------------------------------------------------------
resource "confluent_connector" "oracle_db_cdc_source" {
  environment {
    id = confluent_environment.babu_gko_env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.babu_gko_cluster.id
  }

  config_sensitive = {
    "kafka.api.key"    = confluent_api_key.source_connect_kafka_cluster_key.id
    "kafka.api.secret" = confluent_api_key.source_connect_kafka_cluster_key.secret
    "oracle.username"  = "${var.oracle_username}"
    "oracle.password"  = "${var.oracle_password}"

  }

  config_nonsensitive = {
    "connector.class" = "OracleCdcSource"
    "name"            = "oracle_db_cdc_source"
    "kafka.auth.mode" = "KAFKA_API_KEY"

    "oracle.server" = "babu-oracledb.c598y8lhnjcw.us-east-1.rds.amazonaws.com"
    "oracle.port"   = "1521"
    "oracle.sid"    = "ORACLE"

    "oracle.fan.events.enable"            = "false"
    "table.inclusion.regex"               = "ORACLE[.]TESTADMIN[.](CUSTOMERS|ACCOUNTS)"
    "start.from"                          = "snapshot"
    "oracle.supplemental.log.level"       = "full"
    "emit.tombstone.on.delete"            = "false"
    "behavior.on.dictionary.mismatch"     = "fail"
    "behavior.on.unparsable.statement"    = "fail"
    "db.timezone"                         = "UTC"
    "redo.log.startup.polling.limit.ms"   = "300000"
    "heartbeat.interval.ms"               = "0"
    "query.timeout.ms"                    = "300000"
    "max.batch.size"                      = "1000"
    "poll.linger.ms"                      = "5000"
    "max.buffer.size"                     = "0"
    "redo.log.poll.interval.ms"           = "500"
    "snapshot.row.fetch.size"             = "2000"
    "redo.log.row.fetch.size"             = "5000"
    "oracle.validation.result.fetch.size" = "5000"
    "table.topic.name.template"           = "$${tableName}"
    "redo.log.topic.name"                 = "oracle-cdc-redo-log"
    "topic.creation.redo.partitions"      = 1
    "topic.creation.default.partitions"   = 1
    "oracle.dictionary.mode"              = "auto"
    "output.table.name.field"             = "table"
    "output.scn.field"                    = "scn"
    "output.op.type.field"                = "op_type"
    "output.op.ts.field"                  = "op_ts"
    "output.current.ts.field"             = "current_ts"
    "output.row.id.field"                 = "row_id"
    "output.username.field"               = "username"
    "output.op.type.read.value"           = "R"
    "output.op.type.insert.value"         = "I"
    "output.op.type.update.value"         = "U"
    "output.op.type.delete.value"         = "D"
    "output.op.type.truncate.value"       = "T"
    "snapshot.by.table.partitions"        = "true"
    "snapshot.threads.per.task"           = "4"
    "enable.large.lob.object.support"     = "false"
    "numeric.mapping"                     = "best_fit"
    "numeric.default.scale"               = "127"
    "oracle.date.mapping"                 = "timestamp"
    "output.data.key.format"              = "STRING"
    "output.data.value.format"            = "JSON"
    "tasks.max"                           = "1"
  }

  lifecycle {
    prevent_destroy = false
  }
}


# --------------------------------------------------------
# Mongo DB CDC Sink Connectors
# --------------------------------------------------------
resource "confluent_connector" "mongodb_customers_sink" {
  environment {
    id = confluent_environment.babu_gko_env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.babu_gko_cluster.id
  }

  config_sensitive = {
    "kafka.api.key"       = confluent_api_key.sink_connect_kafka_cluster_key.id
    "kafka.api.secret"    = confluent_api_key.sink_connect_kafka_cluster_key.secret
    "connection.user"     = "${var.mongodb_username}"
    "connection.password" = "${var.mongodb_password}"
  }

  config_nonsensitive = {
    "connector.class"       = "MongoDbAtlasSink"
    "name"                  = "mongodb_customers_sink"
    "input.data.format"     = "JSON"
    "cdc.handler"           = "None"
    "delete.on.null.values" = "true"
    "max.batch.size"        = "0"
    "bulk.write.ordered"    = "true"
    "rate.limiting.timeout" = "0"
    "rate.limiting.every.n" = "0"
    "write.strategy"        = "DefaultWriteModelStrategy"
    "kafka.auth.mode"       = "KAFKA_API_KEY"

    "topics"          = "CUSTOMERS"
    "connection.host" = "bank-crm.na96cwg.mongodb.net"

    "database"                           = "crm_db"
    "collection"                         = "CUSTOMERS"
    "doc.id.strategy"                    = "ProvidedInKeyStrategy"
    "doc.id.strategy.overwrite.existing" = "true"
    "tasks.max"                          = "1"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_connector" "mongodb_accounts_sink" {
  environment {
    id = confluent_environment.babu_gko_env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.babu_gko_cluster.id
  }

  config_sensitive = {
    "connection.user"     = "${var.mongodb_username}"
    "connection.password" = "${var.mongodb_password}"
    "kafka.api.key"       = confluent_api_key.sink_connect_kafka_cluster_key.id
    "kafka.api.secret"    = confluent_api_key.sink_connect_kafka_cluster_key.secret
  }

  config_nonsensitive = {
    "connector.class"                    = "MongoDbAtlasSink"
    "name"                               = "mongodb_customers_sink"
    "input.data.format"                  = "JSON"
    "cdc.handler"                        = "None"
    "delete.on.null.values"              = "true"
    "max.batch.size"                     = "0"
    "bulk.write.ordered"                 = "true"
    "rate.limiting.timeout"              = "0"
    "rate.limiting.every.n"              = "0"
    "write.strategy"                     = "DefaultWriteModelStrategy"
    "kafka.auth.mode"                    = "KAFKA_API_KEY"
    "topics"                             = "ACCOUNTS"
    "connection.host"                    = "bank-crm.na96cwg.mongodb.net"
    "database"                           = "crm_db"
    "collection"                         = "ACCOUNTS"
    "doc.id.strategy"                    = "ProvidedInKeyStrategy"
    "doc.id.strategy.overwrite.existing" = "true"
    "tasks.max"                          = "1"
  }

  lifecycle {
    prevent_destroy = false
  }
}
