
    def reload_addons()
      load_props
      load_addons
    end

    def load_addons()
      if (@addon_list.count == 0)
        LOGGER.debug("No addons specified.")
      else
        @addon_list.each do |addon|
          load File.join(File.dirname(__FILE__), '..', 'addons', "#{addon.underscore}.rb")
          addon_object = Object.const_get("Axial::Addons::#{addon}").new
          @addons.push({name: addon_object.name, version: addon_object.version, author: addon_object.author, object: addon_object})
          addon_object.listeners.each do |listener|
            @binds.push(type: listener[:type], object: addon_object, command: listener[:command], method: listener[:method].to_sym)
          end
        end
      end
    end