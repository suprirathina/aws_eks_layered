#!/usr/bin/env python3
"""
Script to create Lambda deployment package for ALB log processor
"""
import zipfile
import os

def create_lambda_package():
    """Create zip package for Lambda deployment"""
    lambda_dir = os.path.dirname(__file__)
    zip_path = os.path.join(lambda_dir, 'alb_log_processor.zip')
    
    # Remove existing zip if it exists
    if os.path.exists(zip_path):
        os.remove(zip_path)
    
    # Create zip file
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        # Add the main Lambda function
        python_file = os.path.join(lambda_dir, 'alb_log_processor.py')
        if os.path.exists(python_file):
            zipf.write(python_file, 'index.py')  # Rename to index.py for Lambda
            print(f"Added alb_log_processor.py as index.py to {zip_path}")
        else:
            raise FileNotFoundError(f"Python file not found: {python_file}")
    
    print(f"Lambda package created: {zip_path}")
    return zip_path

if __name__ == '__main__':
    create_lambda_package()