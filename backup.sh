#!/bin/bash

# CRONTAB (crontab -e) 0 20 * * 6 /var/backup/backup.sh >> /var/log/backup.log 2>&1

date=$(date +"%Y-%m-%d:%H:%M:%S")

# Début de la configuration

# Database configuration (MariaDB)
db_host="localhost"
db_user="example"
db_password="example"
db_names=("basetest1" "basetest2") # Nom des bases de données MariaDB

# Database configuration (PostgreSQL)
pg_host="localhost"
pg_port="5432"
pg_user="example"
pg_password="example"
pg_names=("basetest3") # Nom des bases de données PostgreSQL

# Path configuration
backup_directory="/var/backup/backups-saved" # Répertoire temporaire de copie des fichiers de backups
app_directory="/var/www" # Répertoire contenant l'ensemble des applications
destination_path="/home/user" # Répertoire de destination des fichiers

app_backup() {

    if [ ! -d "$backup_directory" ]; then
        mkdir $backup_directory
    fi
    if [ -d "$app_directory" ]; then
        if [ "$(find "$backup_directory" -maxdepth 1 -type d | wc -l)" -gt 1 ]; then
            echo "[BACKUP - $date] - Le contenu du répertoire $backup_directory a été supprimé. Vous pouvez redémarrer le script pour effectuer une backup.";
            rm -rf $backup_directory;
            sleep 1;
            mkdir $backup_directory;
            return;
        else
            for app in "$app_directory"/*; do
                echo "[BACKUP - $date] - Enregistrement de ($(basename "$app")) dans le répertoire $backup_directory."
                file_export=$backup_directory/$(basename "$app")-backup-app
                cp -r $app $file_export;
                echo "[BACKUP - $date] - Compression du répertoire $(basename "$app")-backup..."
                tar -czf $destination_path/$(basename "$file_export")-$date.tar.gz -P $backup_directory/$(basename "$app")-backup-app
                sleep 0.5;
            done;

            echo "[BACKUP - $date] - La backup a été créé avec succès."
            rm -rf $backup_directory;

        fi
    else
            echo "[BACKUP - $date] - Le chemin vers le répertoire contenant les applications est invalide, merci de le modifier.";
        return;
    fi
}

database_backup() {
    if [ ${#db_names[@]} -gt 0 ]; then
        for db_name in "${db_names[@]}"; do
            mysqldump --host=$db_host --user=$db_user --password=$db_password --lock-tables $db_name > "/$destination_path/$db_name-backup-db$date.sql"
            if [ $? -eq 0 ]; then
                echo "[BACKUP - $date] - Enregistrement de la base ($db_name) dans le répertoire courrant."
            else
                echo "[BACKUP - $date] - Un erreur s'est produite lors de l'enregistrement de la backup de la base de donnée ($db_name)."
            fi
        done
        if [ ${#pg_names[@]} -gt 0 ]; then
            for pg_name in "${pg_names[@]}"; do
                export PGPASSWORD="$pg_password"
                pg_dump -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_name" -f "$destination_path/$pg_name-backup-db-postgres$date.sql"
                if [ $? -eq 0 ]; then
                    echo "[BACKUP - $date] - Enregistrement de la base postgres ($pg_name) dans le répertoire courrant." & echo "[BACKUP - $date]"
                else
                    echo "[BACKUP - $date] - Un erreur s'est produite lors de l'enregistrement de la backup de la base de donnée postgres ($pg_name)."
                fi
                unset PGPASSWORD;
            done
        fi
    else
        echo "[BACKUP - $date] - Vous n'avez pas renseigner les noms de bases de données.";
    fi
}

rm $destination_path/*.sql && rm $destination_path/*.tar.gz
database_backup && app_backup
