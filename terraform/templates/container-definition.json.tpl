[
    {
        "name": "${name}",
        "image": "${image}",
        "cpu": ${cpu},
        "memory": ${memory},
        "privileged": ${privileged},
        "command": ${command},
        "portMappings": ${portMappings},
        "mountPoints": ${mountPoints},
        "secrets": ${secrets},
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-create-group": "true",
                "awslogs-group": "${namespace}-${env_name}-${service_name}",
                "awslogs-region": "${aws_region}",
                "awslogs-stream-prefix": "ecs"
            }
        }
    }
]