# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module Redmine
  module Export
    module PDF
      module OkrsPdfHelper
        #TODO 当前使用的pdf还未熟识，复杂样式的pdf有待修整
        #
        # Returns a PDF string of a set of okrs record pages
        # https://github.com/naitoh/rbpdf
        def okrs_pages_to_pdf(items)
          pdf = Redmine::Export::PDF::ITCPDF.new(current_language)
          pdf.set_title("okrs")
          pdf.alias_nb_pages
          pdf.footer_date = format_date(User.current.today)
          
          if items.present?
            items.each do |item|
              okrs_page_to_pdf(pdf, item)
            end
          end
          pdf.output
        end

        def okrs_page_to_pdf(pdf, item)
          pdf.add_page
          pdf.SetFontStyle('B',11)
          pdf.RDMMultiCell(190,5, 'OKRS')
          pdf.ln
          # Set resize image scale
          pdf.set_image_scale(1.6)
          pdf.SetFontStyle('',9)

          table_info = item.table_info
          html = ""
          if table_info.present?
            html = html + "<h2>#{item.title}</h2>" 
            hthead = "<thead>
                        <tr>
                          <th>#{l(:okrs_objects_name)}</th>
                          <th>#{l(:okrs_key_result_name)}</th>
                          <th>#{l(:okrs_key_result_supported_by)}</th>
                          <th>#{l(:okrs_key_result_self_score)}</th>
                          <th>#{l(:okrs_key_result_other_score)}</th>
                        </tr>
                      </thead>"
            htbody = ""
            htbody = htbody + "<tbody>"
            table_info.each do |k, v|
              htbody = htbody + "<tr><td rowspan=#{v[:results_count]}>#{v[:name]}</td>"
              v[:results].each do |result|
                htbody = htbody + "<tr>" if result[:index].to_i != 0
                htbody = htbody + "<td>#{simple_format(result[:name])}</td>"
                htbody = htbody + "<td>#{result[:supported_by]}</td>"
                htbody = htbody + "<td>#{result[:self_score]}</td>"
                htbody = htbody + "<td>#{result[:other_score]}</td>"
                htbody = htbody + "</tr>"
              end
            end
            htbody = htbody + "</tbody>"
            htable = "<table border='1'>" + hthead + htbody + "</table>"
            html = html + htable                    
          end
          
          # output the HTML content
          pdf.write_html(html, true, false, true, false, '')
        end
      end
    end
  end
end
