# -*- coding: utf-8 -*-
###############################################################################
#
#   Cybrosys Technologies Pvt. Ltd.
#
#   Copyright (C) 2024-TODAY Cybrosys Technologies(<https://www.cybrosys.com>).
#   Author: Cybrosys Techno Solutions(<https://www.cybrosys.com>)
#
#   You can modify it under the terms of the GNU AFFERO
#   GENERAL PUBLIC LICENSE (AGPL v3), Version 3.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU AFFERO GENERAL PUBLIC LICENSE (AGPL v3) for more details.
#
#   You should have received a copy of the GNU AFFERO GENERAL PUBLIC LICENSE
#   (AGPL v3) along with this program.
#   If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################
import boto3
import dropbox
import ftplib
import nextcloud_client
import os
import paramiko
import requests
from odoo.http import request
from datetime import datetime
from odoo import  api, fields, models


class DatabaseManager(models.Model):
    """ Dashboard model to view all database backups """
    _name = 'database.manager'
    _description = 'Database Manager'

    @api.model
    def action_import_files(self):
        """ Import latest backups from the storages configured """
        return_data = {}
        backup_count = int(self.env['ir.config_parameter'].get_param(
            'odoo_database_restore_manager.backup_count'))
        current_company = request.httprequest.cookies.get('cids')[0]
        # Check if backup_count is less than or equal to 0
        if backup_count <= 0:
            return ['error', 'Please set a backup count', 'Storages',
                    current_company]
        # Check if any backups are configured in the database
        if not self.env['db.backup.configure'].search([]):
            return ['error', 'No Backups Found', 'auto_database_backup',
                    current_company]
        # Loop through each configured backup source
        for rec in self.env['db.backup.configure'].search([]):
            #   For Dropbox
            if rec.backup_destination == 'dropbox':
                try:
                    # Retrieve backups from Dropbox and update the return_data
                    # dictionary with the latest backups
                    dbx_dict = {}
                    dbx = dropbox.Dropbox(app_key=rec.dropbox_client_key,
                                          app_secret=rec.dropbox_client_secret,
                                          oauth2_refresh_token=
                                          rec.dropbox_refresh_token)
                    response = dbx.files_list_folder(path=rec.dropbox_folder)
                    for files in response.entries:
                        file = dbx.files_get_temporary_link(
                            path=files.path_lower)
                        dbx_dict[file.metadata.name] = file.link, 'Dropbox', \
                            files.client_modified
                    return_data.update(dict(list(sorted(dbx_dict.items(),
                                                        key=lambda x: x[1][2],
                                                        reverse=True))[
                                            :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during Dropbox backup
                    # retrieval
                    return ['error', e, 'Dropbox', current_company]
            #   For Onedrive
            if rec.backup_destination == 'onedrive':
                try:
                    # Retrieve backups from OneDrive and update the return_data
                    # dictionary with the latest backups
                    onedrive_dict = {}
                    if rec.onedrive_token_validity <= fields.Datetime.now():
                        rec.generate_onedrive_refresh_token()
                    url = "https://graph.microsoft.com/v1.0/me/drive/items/" \
                          "%s/children?Content-Type=application/json" \
                          % rec.onedrive_folder_key
                    response = requests.request("GET", url, headers={
                        'Authorization': 'Bearer "' + rec.onedrive_access_token + '"'}, data={})
                    for file in response.json().get('value'):
                        if list(file.keys())[
                             0] == '@microsoft.graph.downloadUrl':
                            onedrive_dict[file['name']] = file[
                                '@microsoft.graph.downloadUrl'], 'OneDrive', \
                                datetime.strptime(
                                    file['createdDateTime'],
                                    "%Y-%m-%dT%H:%M:%S.%fZ").strftime(
                                    "%Y-%m-%d %H:%M:%S")
                    return_data.update(dict(list(sorted(onedrive_dict.items(),
                                                        key=lambda x: x[1][2],
                                                        reverse=True))[
                                            :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during OneDrive backup
                    # retrieval
                    return ['error', e, 'OneDrive', current_company]
            #   For Google Drive
            if rec.backup_destination == 'google_drive':
                try:
                    # Retrieve backups from Google Drive and update the
                    # return_data dictionary with the latest backups
                    gdrive_dict = {}
                    if rec.gdrive_token_validity <= fields.Datetime.now():
                        rec.generate_gdrive_refresh_token()
                    response = requests.get(
                        f"https://www.googleapis.com/drive/v3/files",
                        headers={
                            "Authorization": "Bearer %s" % rec.gdrive_access_token
                        },
                        params={
                            "q": f"'{rec.google_drive_folder_key}' in parents",
                            "fields": "files(name, webContentLink, createdTime)",
                        })
                    for file_data in response.json().get("files", []):
                        gdrive_dict[file_data.get("name")] = file_data.get(
                            "webContentLink"), 'Google Drive', \
                            datetime.strptime(file_data.get("createdTime"),
                                              "%Y-%m-%dT%H:%M:%S.%fZ").strftime(
                                "%Y-%m-%d %H:%M:%S")
                    return_data.update(dict(list(sorted(gdrive_dict.items(),
                                                        key=lambda x: x[1][2],
                                                        reverse=True))[
                                            :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during Google Drive
                    # backup retrieval
                    return ['error', e, 'Google Drive', current_company]
            #   For Local Storage
            if rec.backup_destination == 'local':
                try:
                    # Retrieve backups from Local Storage and update the
                    # return_data dictionary with the latest backups
                    local_dict = {}
                    for root, dirs, files in os.walk(rec.backup_path):
                        for file in files:
                            file_path = os.path.join(root, file)
                            create_date = datetime.fromtimestamp(
                                os.path.getctime(file_path)).strftime(
                                "%Y-%m-%d %H:%M:%S")
                            local_dict[file] = file_path, 'Local Storage', \
                                create_date
                    return_data.update(dict(list(sorted(local_dict.items(),
                                                        key=lambda x: x[1][2],
                                                        reverse=True))[
                                            :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during Local Storage
                    # backup retrieval
                    return ['error', e, 'Local', current_company]
            #   For FTP
            if rec.backup_destination == 'ftp':
                try:
                    # Retrieve backups from FTP Storage and update the
                    # return_data dictionary with the latest backups
                    ftp_dict = {}
                    ftp_server = ftplib.FTP()
                    ftp_server.connect(rec.ftp_host, int(rec.ftp_port))
                    ftp_server.login(rec.ftp_user, rec.ftp_password)
                    for file in ftp_server.nlst(rec.ftp_path):
                        file_details = ftp_server.voidcmd("MDTM " + file)
                        ftp_dict[os.path.basename(
                            file)] = file, 'FTP Storage', datetime.strptime(
                            file_details[4:].strip(), "%Y%m%d%H%M%S")
                    ftp_server.quit()
                    return_data.update(dict(list(sorted(ftp_dict.items(),
                                                        key=lambda x: x[1][2],
                                                        reverse=True))[
                                            :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during FTP Storage
                    # backup retrieval
                    return ['error', e, 'FTP server', current_company]
            #   For SFTP
            if rec.backup_destination == 'sftp':
                sftp_client = paramiko.SSHClient()
                sftp_client.set_missing_host_key_policy(
                    paramiko.AutoAddPolicy())
                try:
                    # Retrieve backups from SFTP Storage and update the
                    # return_data dictionary  with the latest backups
                    sftp_dict = {}
                    sftp_client.connect(hostname=rec.sftp_host,
                                        username=rec.sftp_user,
                                        password=rec.sftp_password,
                                        port=rec.sftp_port)
                    sftp_server = sftp_client.open_sftp()
                    sftp_server.chdir(rec.sftp_path)
                    file_list = sftp_server.listdir()
                    for file_name in file_list:
                        sftp_dict[file_name] = os.path.join(rec.sftp_path,
                                                            file_name), \
                            'SFTP Storage', datetime.fromtimestamp(
                            sftp_server.stat(file_name).st_mtime)
                    sftp_server.close()
                    return_data.update(dict(list(sorted(sftp_dict.items(),
                                                        key=lambda x: x[1][2],
                                                        reverse=True))[
                                            :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during SFTP Storage
                    # backup retrieval
                    return ['error', e, 'SFTP server', current_company]
                finally:
                    sftp_client.close()
            #   For Next Cloud
            if rec.backup_destination == 'next_cloud':
                try:
                    nxt_dixt = {}
                    nc_access = nextcloud_client.Client(rec.domain)
                    nc_access.login(rec.next_cloud_user_name,
                                    rec.next_cloud_password)
                    for file_name in [file.name for file in
                                      nc_access.list(
                                          '/' + rec.nextcloud_folder_key)]:
                        link_info = nc_access.share_file_with_link(
                            '/' + rec.nextcloud_folder_key + '/' + file_name,
                            publicUpload=False)
                        file_info = nc_access.file_info(
                            '/' + rec.nextcloud_folder_key + '/' + file_name)
                        input_datetime = datetime.strptime(
                            file_info.attributes['{DAV:}getlastmodified'],
                            "%a, %d %b %Y %H:%M:%S %Z")
                        output_date_str = input_datetime.strftime(
                            "%Y-%m-%d %H:%M:%S")
                        nxt_dixt[
                            file_name] = link_info.get_link() + '/download', 'Nextcloud', output_date_str
                    return_data.update(dict(list(sorted(nxt_dixt.items(),
                                                        key=lambda x: x[1][2],
                                                        reverse=True))[
                                            :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during SFTP Storage
                    # backup retrieval
                    return ['error', e, 'Nextcloud', current_company]
            #   For Amazon S3
            if rec.backup_destination == 'amazon_s3':
                try:
                    s3_dixt = {}
                    client = boto3.client('s3', aws_access_key_id=rec.aws_access_key,
                                          aws_secret_access_key=rec.aws_secret_access_key)
                    region = client.get_bucket_location(Bucket=rec.bucket_file_name)
                    client = boto3.client(
                        's3', region_name=region['LocationConstraint'],
                        aws_access_key_id=rec.aws_access_key,
                        aws_secret_access_key=rec.aws_secret_access_key
                    )
                    response = client.list_objects(Bucket=rec.bucket_file_name, Prefix=rec.aws_folder_name)
                    for data in response['Contents']:
                        if data['Size'] != 0:
                             url = client.generate_presigned_url(
                                 ClientMethod='get_object',
                                 Params={'Bucket': rec.bucket_file_name,
                                         'Key': data['Key']},ExpiresIn=3600)
                             s3_dixt[data['Key']] = url, 'AmazonS3', data['LastModified']
                    return_data.update(dict(list(sorted(s3_dixt.items(),
                                                            key=lambda x: x[1][2],
                                                            reverse=True))[
                                                :backup_count]))
                except Exception as e:
                    # Handle any exceptions that occur during amazon_s3 Storage
                    # backup retrieval
                    return ['error', e, 'Amazon S3', current_company]

        # Return the dictionary containing the latest backups from all
        # configured sources
        return [return_data, current_company]
