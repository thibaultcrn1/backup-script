#!/bin/sh

# CRONTAB (crontab -e) 0 20 * * 6 /var/backup/backup.sh

date=$(date +"%Y-%m-%d:%H:%M:%S")

# Début de la configuration

# Database configuration (MariaDB)
db_host="example"
db_user="example"
db_password="example"
db_names=("basetest1" "basetest2") # Nom des bases de données MariaDB

# Database configuration (PostgreSQL)
pg_host="example"
pg_port="5432"
pg_user="example"
pg_password="example"
pg_names=("basetest3" "basetest4") # Nom des bases de données PostgreSQL

# Path configuration
backup_directory="./backups-saved" # Répertoire temporaire de copie des fichiers de backups
app_directory="./app-deploy" # Répertoire contenant l'ensemble des applications
log_file="./log/backup.log" # Fichier log

app_backup() {

    if [ ! -d "$backup_directory" ]; then
        mkdir $backup_directory
    fi
    if [ -d "$app_directory" ]; then
        if [ "$(find "$backup_directory" -maxdepth 1 -type d | wc -l)" -gt 1 ]; then
            echo "[BACKUP] - Le contenu du répertoire $backup_directory a été supprimé. Vous pouvez redémarrer le script pour effectuer une backup.";
            rm -rf $backup_directory;
            sleep 1;
            mkdir $backup_directory;
            return;
        else
            for app in "$app_directory"/*; do
                echo "[BACKUP] - Enregistrement de ($(basename "$app")) dans le répertoire $backup_directory."
                file_export=$backup_directory/$(basename "$app")-backup-app
                cp -r $app $file_export;
                echo "[BACKUP] - Compression du répertoire $(basename "$app")-backup..."
                tar -czf $(basename "$file_export")-app$date.tar.gz $backup_directory/$(basename "$app")-backup-app
                sleep 0.5;
            done;

            echo "[BACKUP] - La backup a été créé avec succès." & echo "[BACKUP - $date] - La backup a été créé avec succès." >> $log_file;
            rm -rf $backup_directory;

        fi
    else
            echo "[BACKUP] - Le chemin vers le répertoire contenant les applications est invalide, merci de le modifier.";
        return;
    fi
}

database_backup() {
    if [ ${#db_names[@]} -gt 0 ]; then
        for db_name in "${db_names[@]}"; do
            mysqldump --host=$db_host --user=$db_user --password=$db_password --lock-tables $db_name > "$db_name-backup-db$date.sql"
            if [ $? -eq 0 ]; then
                echo "[BACKUP] - Enregistrement de la base ($db_name) dans le répertoire courrant." & echo "[BACKUP - $date] - Enregistrement de la base ($db_name) dans le répertoire courrant." >> $log_file;
            else
                echo "[BACKUP] - Un erreur s'est produite lors de l'enregistrement de la backup de la base de donnée ($db_name)." & echo "[BACKUP - $date] - Une erreur s'est produite lors de l'enregistrement de la backup de la base de donnée ($db_name)." >> $log_file;
            fi
        done
        if [ ${#pg_names[@]} -gt 0 ]; then
            for pg_name in "${pg_names[@]}"; do
                export PGPASSWORD="pg_password"
                pg_dump -h "$pg_host" -p "$pg_port" -U "$pg_user" -d "$pg_name" -f "$pg_name-backup-db-postgres$date.sql"
                if [ $? -eq 0 ]; then
                    echo "[BACKUP] - Enregistrement de la base postgres ($pg_name) dans le répertoire courrant." & echo "[BACKUP - $date] - Enregistrement de la base postgres ($pg_name) dans le répertoire courrant." >> $log_file;
                else
                    echo "[BACKUP] - Un erreur s'est produite lors de l'enregistrement de la backup de la base de donnée postgres ($pg_name)." & echo "[BACKUP - $date] - Une erreur s'est produite lors de l'enregistrement de la backup de la base de donnée postgres ($pg_name)." >> $log_file;
                fi
                unset PGPASSWORD;
            done
        fi
    else
        echo "[BACKUP - $date] - Vous n'avez pas renseigner les noms de bases de données." >> $log_file;
    fi
}

rm -f ./*-backup-db* & sleep 0.5 & database_backup & rm -f ./*-backup-db* & rm -f ./*-backup-app* & sleep 0.5 & database_backup & app_backup