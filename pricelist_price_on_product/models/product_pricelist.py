# -*- coding: utf-8 -*-
################################################################################
#
#    Cybrosys Technologies Pvt. Ltd.
#
#    Copyright (C) 2024-TODAY Cybrosys Technologies(<https://www.cybrosys.com>).
#    Author: MOHAMMED DILSHAD TK (odoo@cybrosys.com)
#
#    You can modify it under the terms of the GNU AFFERO
#    GENERAL PUBLIC LICENSE (AGPL v3), Version 3.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU AFFERO GENERAL PUBLIC LICENSE (AGPL v3) for more details.
#
#    You should have received a copy of the GNU AFFERO GENERAL PUBLIC LICENSE
#    (AGPL v3) along with this program.
#    If not, see <http://www.gnu.org/licenses/>.
#
################################################################################
from odoo import api, fields, models
from odoo.exceptions import ValidationError


class ProductPricelist(models.Model):
    """
    Inherits from 'product.pricelist' to add a boolean field for displaying
    pricelist prices in product forms. Also ensures correct handling of
    O2m fields and potential errors.
    """
    _inherit = 'product.pricelist'

    display_pricelist = fields.Boolean(string='Display Pricelist Price on Products',
                                       help='If checked, the pricelist price will be displayed in product forms.')

    @api.onchange('display_pricelist', 'item_ids')
    def _onchange_display_pricelist(self):
        """
        Updates product pricelist prices based on 'display_pricelist' and 'item_ids' changes.
        - Handles potential cases where `item.ids` might be empty.
        - Uses `ensure_one()` to guarantee a single record for clarity.
        - Employs `filtered()` to find existing pricelist items without errors.
        """
        self.ensure_one()
        for line in self.item_ids:
            product = line.product_tmpl_id
            pricelist = line.pricelist_id._origin
            pricelist_ids = product.product_pricelist_ids.filtered(
                lambda p: p.product_price_id == pricelist)
            if self.display_pricelist:
                if not pricelist_ids:
                    if not pricelist:
                        raise ValidationError("Save the price list, "
                                              "otherwise the price could not save in the product")
                    product.write({
                        'product_pricelist_ids': [fields.Command.create({
                            'product_price_id': pricelist.id,
                            'product_price': line.fixed_price,
                        })]
                    })
                else:
                    existing_pricelist = pricelist_ids[0]  # Access the first element
                    existing_pricelist.write({'product_price': line.fixed_price})
            else:
                if pricelist_ids:
                    pricelist_ids.unlink()
