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
import ftplib
import gdown
import os
import paramiko
import requests
import tempfile
import odoo
import odoo.modules.registry
from odoo import fields, models
from odoo.exceptions import UserError
from odoo.http import dispatch_rpc
from odoo.service import db
from odoo.tools.misc import str2bool


class DataBaseRestore(models.TransientModel):
    """ Database Restore Model """
    _name = "database.restore"
    _description = "Database Restore"

    db_file = fields.Char(string="File", help="Restore database file")
    db_name = fields.Char(string="Database Name", help="Name of the database")
    db_master_pwd = fields.Char(string="Database Master Password",
                                help="Master Password to restore database")
    backup_location = fields.Char(string="Backup Location",
                                  help="Database backup location")

    def action_restore_database(self, copy=False):
        """ Function to restore the database Backup """
        # Check if the admin password is insecure and update it if provided
        insecure = odoo.tools.config.verify_admin_password('admin')
        if insecure and self.db_master_pwd:
            dispatch_rpc('db', 'change_admin_password',
                         ["admin", self.db_master_pwd])
        try:
            # Check if the admin password is correct and proceed with the
            # restore process
            db.check_super(self.db_master_pwd)
            # Create a temporary file to store the downloaded backup data
            temp_file = tempfile.NamedTemporaryFile(delete=False)
            if self.backup_location == 'Google Drive':
                # Retrieve backup from Google Drive using gdown library
                gdown.download(self.db_file, temp_file.name, quiet=False)
            elif self.backup_location in ['Dropbox', 'OneDrive', 'Nextcloud', 'AmazonS3']:
                # Retrieve backup from Dropbox or OneDrive using requests
                # library
                response = requests.get(self.db_file, stream=True)
                temp_file.write(response.content)
            elif self.backup_location == 'FTP Storage':
                # Retrieve backup from FTP Storage using ftplib
                for rec in self.env['db.backup.configure'].search([]):
                    if rec.backup_destination == 'ftp' and rec.ftp_path == \
                            os.path.dirname(self.db_file):
                        ftp_server = ftplib.FTP()
                        ftp_server.connect(rec.ftp_host, int(rec.ftp_port))
                        ftp_server.login(rec.ftp_user, rec.ftp_password)
                        ftp_server.retrbinary("RETR " + self.db_file,
                                              temp_file.write)
                        temp_file.seek(0)
                        ftp_server.quit()
            elif self.backup_location == 'SFTP Storage':
                # Retrieve backup from SFTP Storage using paramiko
                for rec in self.env['db.backup.configure'].search([]):
                    if rec.backup_destination == 'sftp' and rec.sftp_path == \
                            os.path.dirname(self.db_file):
                        sftp_client = paramiko.SSHClient()
                        sftp_client.set_missing_host_key_policy(
                            paramiko.AutoAddPolicy())
                        sftp_client.connect(hostname=rec.sftp_host,
                                            username=rec.sftp_user,
                                            password=rec.sftp_password,
                                            port=rec.sftp_port)
                        sftp_server = sftp_client.open_sftp()
                        sftp_server.getfo(self.db_file, temp_file)
                        sftp_server.close()
                        sftp_client.close()
            elif self.backup_location == 'Local Storage':
                # If the backup is stored in the local storage, set the temp
                # file's name accordingly
                temp_file.name = self.db_file
            # Restore the database using Odoo's 'restore_db' method
            db.restore_db(self.db_name, temp_file.name, str2bool(copy))
            temp_file.close()
            # Redirect the user to the Database Manager after successful
            # restore
            return {
                'type': 'ir.actions.act_url',
                'url': '/web/database/manager'
            }
        except Exception as e:
            # Raise a UserError if any error occurs during the database
            # restore process
            raise UserError(
                "Database restore error: %s" % (str(e) or repr(e)))
