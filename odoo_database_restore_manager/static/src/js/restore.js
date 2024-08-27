/* @odoo-module */
import { useService } from "@web/core/utils/hooks";
import { Component, onWillStart, useState } from "@odoo/owl";
import {registry} from '@web/core/registry';


export class DbRestoreDashboard extends Component {
    setup() {
        super.setup(...arguments);
        this.dbDashboard = useState({ data: [] })
        this.orm = useService("orm");
        this.action = useService("action");
        onWillStart(async () => {
            await this.loadDashboardData();
        });
    }
    async loadDashboardData() {
        const database_file = await this.orm.call(
            'database.manager',
            'action_import_files',
            []
        );
        if (database_file[0] == 'error'){
            this.action.doAction({
                'type': 'ir.actions.client',
                'tag': 'display_notification',
                'params': {
                    'message': 'Failed to Load Files from ' + database_file[2] + ' [ ' + database_file[1] + ' ]',
                    'type': 'warning',
                    'sticky': false,
                }
            });
        }
        else {
            this.dbDashboard.data = Object.entries(database_file[0]).map(([file_name, values]) => {
                return {
                    'file_name': file_name,
                    'values': values
                };
            });
        }
    }
//    Function for restore the database
    _onClick_restore(ev) {
        this.action.doAction({
        name: "Restore Database",
        type: 'ir.actions.act_window',
        res_model: 'database.restore',
        view_mode: 'form',
        view_type: 'form',
        views: [[false, 'form']],
        context: {
          default_db_file: ev.target.value,
          default_backup_location: ev.target.dataset.location
        },
        target: 'new',
      });
    }
    isValidBackupName(name) {
        return ['Dropbox', 'OneDrive', 'Google Drive' , 'Nextcloud', 'AmazonS3'].includes(name)
    }
//    Filter for location
    _onchange_location(ev) {
        var e = ev.target.value
        var self = this;
        $('.table_row').show();
        $('.table_row').each(function(index, element) {
            if (e == 'all_backups') {
                $('.table_row').show();
            }
            else if ($(element)[0].children[2].innerHTML != e){
                $(element).hide();
            }
        });
    };
}
registry.category("actions").add("database_manager_dashboard", DbRestoreDashboard);
DbRestoreDashboard.components = { DbRestoreDashboard };
DbRestoreDashboard.template = 'database_manager_dashboard.DbRestoreDashboard';
