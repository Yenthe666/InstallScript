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
{
    'name': "Database Restore Manager",
    'version': "17.0.1.0.0",
    'category': "Extra Tools",
    'summary': """Database Restore Manager,Restore Manager,Odoo Database Backup, Automatic Backup, Database Backup, Automatic Backup,Database auto-backup, odoo backup'
               'google drive, dropbox, nextcloud, amazon S3, onedrive or '
               'remote server, Odoo17""",
    'description': """The Database Restore Manager allows users to easily 
     restore and download backups uploaded by the auto_database_backup module,
     providing convenient backup management within the platform""",
    'author': 'Cybrosys Techno Solutions',
    'company': 'Cybrosys Techno Solutions',
    'maintainer': 'Cybrosys Techno Solutions',
    'website': "https://www.cybrosys.com",
    'depends': ['base_setup', 'auto_database_backup'],
    'data': [
        'security/ir.model.access.csv',
        'views/database_manager_views.xml',
        'views/res_config_settings_views.xml',
        'wizard/database_restore_views.xml'
    ],
    'assets': {
        'web.assets_backend': [
            '/odoo_database_restore_manager/static/src/js/restore.js',
            '/odoo_database_restore_manager/static/src/xml/db_restore_dashboard_templates.xml',
            '/odoo_database_restore_manager/static/src/scss/db_restore.scss'
        ]
    },
    'external_dependencies': {'python': ['dropbox', 'gdown']},
    'images': ['static/description/banner.jpg'],
    'license': 'AGPL-3',
    'installable': True,
    'auto_install': False,
    'application': False,
}
