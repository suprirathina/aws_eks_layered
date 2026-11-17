"""
ALB Access Log Processor for CloudWatch Integration
Processes ALB access logs from S3 and sends key metrics to CloudWatch
"""
import json
import boto3
import gzip
import urllib.parse
import os
from datetime import datetime
import re

# Initialize AWS clients
cloudwatch = boto3.client('cloudwatch')
s3 = boto3.client('s3')

def handler(event, context):
    """
    Lambda handler to process ALB access logs from S3
    """
    try:
        # Get environment variables
        log_group_name = os.environ['LOG_GROUP_NAME']
        project_name = os.environ['PROJECT_NAME']
        environment = os.environ['ENVIRONMENT']
        
        # Process each S3 record
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = urllib.parse.unquote_plus(record['s3']['object']['key'])
            
            print(f"Processing ALB log file: s3://{bucket}/{key}")
            
            # Download and process the log file
            metrics = process_alb_log_file(bucket, key)
            
            # Send metrics to CloudWatch
            if metrics:
                send_metrics_to_cloudwatch(metrics, project_name, environment)
                
        return {
            'statusCode': 200,
            'body': json.dumps('Successfully processed ALB logs')
        }
        
    except Exception as e:
        print(f"Error processing ALB logs: {str(e)}")
        raise e

def process_alb_log_file(bucket, key):
    """
    Download and parse ALB access log file from S3
    """
    try:
        # Download log file
        response = s3.get_object(Bucket=bucket, Key=key)
        
        # Handle gzipped files
        if key.endswith('.gz'):
            content = gzip.decompress(response['Body'].read()).decode('utf-8')
        else:
            content = response['Body'].read().decode('utf-8')
        
        # Parse ALB log lines
        metrics = {
            'total_requests': 0,
            'status_2xx': 0,
            'status_3xx': 0,
            'status_4xx': 0,
            'status_5xx': 0,
            'response_times': [],
            'target_response_times': [],
            'request_sizes': [],
            'response_sizes': []
        }
        
        for line in content.strip().split('\n'):
            if line:
                parsed_log = parse_alb_log_line(line)
                if parsed_log:
                    update_metrics(metrics, parsed_log)
        
        return calculate_aggregated_metrics(metrics)
        
    except Exception as e:
        print(f"Error processing log file {key}: {str(e)}")
        return None

def parse_alb_log_line(log_line):
    """
    Parse a single ALB access log line
    ALB log format: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html
    """
    try:
        # Split log line (space-separated, with quoted fields)
        fields = re.findall(r'(?:[^\s"]+|"[^"]*")+', log_line)
        
        if len(fields) < 29:  # ALB logs have many fields
            return None
            
        return {
            'timestamp': fields[1],
            'elb': fields[2],
            'client_ip': fields[3].split(':')[0],
            'target': fields[4],
            'request_processing_time': float(fields[5]) if fields[5] != '-1' else 0,
            'target_processing_time': float(fields[6]) if fields[6] != '-1' else 0,
            'response_processing_time': float(fields[7]) if fields[7] != '-1' else 0,
            'elb_status_code': int(fields[8]) if fields[8] != '-1' else 0,
            'target_status_code': fields[9],
            'received_bytes': int(fields[10]) if fields[10] != '-1' else 0,
            'sent_bytes': int(fields[11]) if fields[11] != '-1' else 0,
            'request': fields[12],
            'user_agent': fields[13],
            'ssl_cipher': fields[14],
            'ssl_protocol': fields[15]
        }
    except Exception as e:
        print(f"Error parsing log line: {str(e)}")
        return None

def update_metrics(metrics, parsed_log):
    """
    Update metrics with data from a parsed log entry
    """
    # Count total requests
    metrics['total_requests'] += 1
    
    # Count by status code
    status_code = parsed_log['elb_status_code']
    if 200 <= status_code < 300:
        metrics['status_2xx'] += 1
    elif 300 <= status_code < 400:
        metrics['status_3xx'] += 1
    elif 400 <= status_code < 500:
        metrics['status_4xx'] += 1
    elif 500 <= status_code < 600:
        metrics['status_5xx'] += 1
    
    # Collect response times
    total_time = (parsed_log['request_processing_time'] + 
                  parsed_log['target_processing_time'] + 
                  parsed_log['response_processing_time'])
    if total_time > 0:
        metrics['response_times'].append(total_time)
        
    if parsed_log['target_processing_time'] > 0:
        metrics['target_response_times'].append(parsed_log['target_processing_time'])
    
    # Collect request/response sizes
    metrics['request_sizes'].append(parsed_log['received_bytes'])
    metrics['response_sizes'].append(parsed_log['sent_bytes'])

def calculate_aggregated_metrics(metrics):
    """
    Calculate aggregated metrics from raw data
    """
    total_requests = metrics['total_requests']
    if total_requests == 0:
        return None
        
    # Calculate percentages
    status_2xx_percent = (metrics['status_2xx'] / total_requests) * 100
    status_4xx_percent = (metrics['status_4xx'] / total_requests) * 100
    status_5xx_percent = (metrics['status_5xx'] / total_requests) * 100
    
    # Calculate response time statistics
    response_times = metrics['response_times']
    avg_response_time = sum(response_times) / len(response_times) if response_times else 0
    max_response_time = max(response_times) if response_times else 0
    
    # Calculate p95 response time
    p95_response_time = 0
    if response_times:
        sorted_times = sorted(response_times)
        p95_index = int(len(sorted_times) * 0.95)
        p95_response_time = sorted_times[p95_index] if p95_index < len(sorted_times) else sorted_times[-1]
    
    # Calculate throughput (requests per minute, assuming 1-minute log file)
    throughput = total_requests
    
    return {
        'TotalRequests': total_requests,
        'Status2xxPercent': status_2xx_percent,
        'Status4xxPercent': status_4xx_percent,
        'Status5xxPercent': status_5xx_percent,
        'AverageResponseTime': avg_response_time,
        'MaxResponseTime': max_response_time,
        'P95ResponseTime': p95_response_time,
        'Throughput': throughput,
        'ErrorRate': status_4xx_percent + status_5xx_percent
    }

def send_metrics_to_cloudwatch(metrics, project_name, environment):
    """
    Send aggregated metrics to CloudWatch
    """
    try:
        namespace = 'ALB/ProcessedMetrics'
        timestamp = datetime.utcnow()
        
        # Prepare metric data
        metric_data = []
        
        for metric_name, value in metrics.items():
            metric_data.append({
                'MetricName': metric_name,
                'Value': value,
                'Unit': 'None',
                'Timestamp': timestamp,
                'Dimensions': [
                    {
                        'Name': 'Project',
                        'Value': project_name
                    },
                    {
                        'Name': 'Environment',
                        'Value': environment
                    }
                ]
            })
        
        # Send metrics in batches (CloudWatch limit is 20 metrics per call)
        for i in range(0, len(metric_data), 20):
            batch = metric_data[i:i+20]
            cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=batch
            )
        
        print(f"Successfully sent {len(metric_data)} metrics to CloudWatch")
        
    except Exception as e:
        print(f"Error sending metrics to CloudWatch: {str(e)}")
        raise e