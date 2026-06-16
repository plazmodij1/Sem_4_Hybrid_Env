data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "monitoring" {
  name   = "monitoring-sg"
  vpc_id = aws_vpc.public.id

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node Exporter from same SG"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "monitoring-sg"
  }
}

resource "aws_iam_role" "grafana_ec2_role" {
  name = "grafana-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch_readonly" {
  role       = aws_iam_role.grafana_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "grafana_logs_readonly" {
  role       = aws_iam_role.grafana_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "grafana_ssm_core" {
  role       = aws_iam_role.grafana_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "grafana_profile" {
  name = "grafana-ec2-profile"
  role = aws_iam_role.grafana_ec2_role.name
}

resource "aws_instance" "grafana" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public["dmz-1"].id
  vpc_security_group_ids      = [aws_security_group.monitoring.id]
  iam_instance_profile        = aws_iam_instance_profile.grafana_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -eux

              apt-get update
              apt-get install -y apt-transport-https software-properties-common wget curl gpg

              # Grafana
              mkdir -p /etc/apt/keyrings
              wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
              echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

              apt-get update
              apt-get install -y grafana prometheus

              # node_exporter
              useradd --no-create-home --shell /bin/false node_exporter || true
              cd /tmp
              wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
              tar xvf node_exporter-1.8.2.linux-amd64.tar.gz
              cp node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
              chown node_exporter:node_exporter /usr/local/bin/node_exporter

              cat >/etc/systemd/system/node_exporter.service <<'EON'
              [Unit]
              Description=Node Exporter
              Wants=network-online.target
              After=network-online.target

              [Service]
              User=node_exporter
              Group=node_exporter
              Type=simple
              ExecStart=/usr/local/bin/node_exporter

              [Install]
              WantedBy=multi-user.target
              EON

              # Prometheus config
              cat >/etc/prometheus/prometheus.yml <<'EOP'
              global:
                scrape_interval: 15s

              scrape_configs:
                - job_name: prometheus
                  static_configs:
                    - targets: ['localhost:9090']

                - job_name: node_exporter
                  static_configs:
                    - targets: ['localhost:9100']
              EOP

              mkdir -p /etc/grafana/provisioning/datasources
              cat >/etc/grafana/provisioning/datasources/datasource.yml <<'EOG'
              apiVersion: 1

              datasources:
                - name: Prometheus
                  type: prometheus
                  access: proxy
                  url: http://localhost:9090
                  isDefault: true

                - name: CloudWatch
                  type: cloudwatch
                  access: proxy
                  jsonData:
                    authType: default
                    defaultRegion: eu-central-1
              EOG

              systemctl daemon-reload
              systemctl enable prometheus
              systemctl restart prometheus
              systemctl enable node_exporter
              systemctl start node_exporter
              systemctl enable grafana-server
              systemctl start grafana-server
              EOF

  tags = {
    Name = "grafana-monitoring"
  }
}

output "grafana_url" {
  value = "http://${aws_instance.grafana.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.grafana.public_ip}:9090"
}