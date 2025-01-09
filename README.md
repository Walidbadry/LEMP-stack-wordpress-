# LEMP Stack Deployment

This repository provides a guide for deploying a LEMP (Linux, Nginx, MySQL, PHP) stack application. Follow the steps below to set up and deploy your application.

## Prerequisites

Ensure the following are installed on your server:

- **Linux**: Ubuntu 20.04+ is recommended.
- **Nginx**: A web server to handle HTTP requests.
- **MySQL**: A database to store application data.
- **PHP**: To process dynamic content.

## Steps to Deploy the LEMP Stack

### 1. Update and Install Required Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mysql-server php-fpm php-mysql unzip
```

### 2. Configure Nginx

1. Create an Nginx configuration file for your application:

    ```bash
    sudo nano /etc/nginx/sites-available/your-app
    ```

2. Add the following configuration:

    ```nginx
    server {
        listen 80;
        server_name your-domain.com;

        root /var/www/your-app;
        index index.php index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }

        location ~ /\.ht {
            deny all;
        }
    }
    ```

3. Enable the configuration:

    ```bash
    sudo ln -s /etc/nginx/sites-available/your-app /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx
    ```

### 3. Set Up MySQL Database

1. Secure MySQL installation:

    ```bash
    sudo mysql_secure_installation
    ```

2. Log in to MySQL and create a database:

    ```bash
    sudo mysql -u root -p
    CREATE DATABASE your_app_db;
    CREATE USER 'your_user'@'localhost' IDENTIFIED BY 'your_password';
    GRANT ALL PRIVILEGES ON your_app_db.* TO 'your_user'@'localhost';
    FLUSH PRIVILEGES;
    EXIT;
    ```

### 4. Deploy Application Files

1. Upload your application files to `/var/www/your-app`:

    ```bash
    sudo mkdir -p /var/www/your-app
    sudo cp -r /path/to/your/app/* /var/www/your-app
    sudo chown -R www-data:www-data /var/www/your-app
    sudo chmod -R 755 /var/www/your-app
    ```

### 5. Test the Application

1. Open your browser and navigate to `http://your-domain.com`.
2. Ensure that your application is running correctly.

## Troubleshooting

- Check the Nginx logs:
  ```bash
  sudo tail -f /var/log/nginx/error.log
  ```

- Check PHP logs:
  ```bash
  sudo tail -f /var/log/php7.4-fpm.log
  ```

- Ensure MySQL service is running:
  ```bash
  sudo systemctl status mysql
  ```

## Notes

- Replace `your-domain.com`, `your-app`, `your_user`, and `your_password` with your specific details.
- Adjust the PHP-FPM socket path if using a different version of PHP.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
