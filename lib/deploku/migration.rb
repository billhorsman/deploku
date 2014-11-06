module Deploku
  class Migration < OpenStruct

    attr_accessor :local_status, :remote_status

    def pending?
      local_status != "up" || remote_status != "up"
    end

    def to_s
      message = case local_status
      when "down"
        case remote_status
        when "down"
          "Pending locally and remotely. Why?"
        when "up"
          "Pending locally BUT up remotely. Why?"
        else
          "Pending locally AND needs to be deployed. Migrate locally first?"
        end
      when "up"
        case remote_status
        when "down"
          "Pending remotely"
        when "up"
          "Up both locally and remotely"
        else
          "Needs to be deployed"
        end
      else
        case remote_status
        when "down"
          "Pending remotely but missing locally!"
        when "up"
          "Up remotely but pending locally!"
        else
          "Missing locally and remotely!!"
        end
      end
      "  #{version} - #{message}"
    end

  end
end
