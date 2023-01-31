output "env_info"{
  value = {
    env_id = confluent_environment.babu_gko_env.id
    cluster_id = confluent_kafka_cluster.babu_gko_cluster.id
  }
}

output "source_connect_api_key"{
  sensitive = true
  value = {
    api-key = confluent_api_key.source_connect_kafka_cluster_key.id
    api-secret =confluent_api_key.source_connect_kafka_cluster_key.secret
    
  }
}

output "sink_connect_api_key"{
  sensitive = true
  value = {
    api-key = confluent_api_key.sink_connect_kafka_cluster_key.id
    api-secret =confluent_api_key.sink_connect_kafka_cluster_key.secret
    
  }
}

output "sr_cluster_key"{
  sensitive = true
  value = {
    api-key = confluent_api_key.sr_cluster_key.id
    api-secret =confluent_api_key.sr_cluster_key.secret
    
  }
}