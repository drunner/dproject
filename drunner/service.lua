-- drunner service configuration for dProject

function drunner_setup()
-- addvolume(NAME, [BACKUP], [EXTERNAL])
   addvolume("drunner-${SERVICENAME}-config")
end

-- everything past here are functions that can be run from the commandline,
-- e.g. helloworld run

function chownpath(path, command)
   -- [ -d "$DPATH" ] || die "chownpath called with non-existant path $DPATH"

   -- set ownership and permissions for those support files (don't rely on what's in the container).
   drun("docker", "run", "--rm", "-v", path..":/s", "drunner/rootutils", "bash -c \""..command.."\"")
   if result~=0 then
     print("chownpath command failed: "..command)
   end
end

function splitString(input)
   local result = {}
   local index = 1
   local spat, epat, buf, quoted = [=[^(['"])]=], [=[(['"])$]=]
   for str in input:gmatch("%S+") do
      local squoted = str:match(spat)
      local equoted = str:match(epat)
      local escaped = str:match([=[(\*)['"]$]=])
      if squoted and not quoted and not equoted then
         buf, quoted = str, squoted
      elseif buf and equoted == quoted and #escaped % 2 == 0 then
         str, buf, quoted = buf .. ' ' .. str, nil, nil
      elseif buf then
         buf = buf .. ' ' .. str
      end
      if not buf then
         result[index] = (str:gsub(spat,""):gsub(epat,""))
         index = index + 1
      end
   end
   ---if buf then print("Missing matching quote for "..buf) end
   return result
end

function dockerrun(command, arguments)
   return drun("docker", "run", "-i", "--rm", "--name=dproject-"..command, "-v", "drunner-${SERVICENAME}-config:/config", "${IMAGENAME}", command, arguments)
end

function dockerrun_output(command, arguments)
   return drun_output("docker", "run", "-i", "--rm", "--name=dproject-"..command, "-v", "drunner-${SERVICENAME}-config:/config", "${IMAGENAME}", command, arguments)
end

function create(...)
   local projectName = arg[0]
   local projectPath = projectName
   if arg[n] > 1 then
      projectPath = arg[1]
   end

   -- Create project directory
   drun("mkdir", "-p", projectPath)

   -- allow the container to write into this folder.
   drun("chmod", "0777", projectPath)

   -- get user id
   local userId = drun_output("id", "-u")

   -- get group id
   local groupId = drun_output("id", "-g")

   -- Copy out project files
   drun("docker", "run", "--rm", "-i", "--user=\""..userId..":"..groupId.."\"",
         "-v", projectPath..":/tempcopy", "${IMAGENAME}", "/bin/bash -c \"cp -r /project/. /tempcopy/\"")

   -- Replace <<PROJECT_NAME>> with $PROJECT_NAME
   local fileList = drun_output("grep", "-rl", "<<PROJECT_NAME>>", projectPath)
   for file in string.gmatch(fileList, "[^\n]+") do
      drun_output("sed", "-i", "s/<<PROJECT_NAME>>/"..projectName.."/g", file)
   end

   -- Set permissions on new files
   chownpath(projectPath, "chown -R $EUID:${GROUPS[0]} /s && chmod -R 0644 /s")

   print("Project \""..projectName.."\" has been created in \""..projectPath.."\"!")
   print("Create a Git repository and branch to start development:")
   print("   cd "..projectPath)
   print("   git init")
   print("   git commit -m \"Project created\"")
   print("   git checkout -b dev")
   print("")
   print("You now have a Git repository on a dev branch to begin developing!")
end

function setup()
   if not string.find(drun_output("dpkg", "-l"), "cifs-utils", 1, true) then
      print("Installing cifs-utils...")
      drun("sudo", "apt-get", "update")
      drun("sudo", "apt-get", "install", "-y", "cifs-utils")
      print("Finished installing cifs-utils, resuming setup")
      print("")
   end

   print("//////////////////////////////////////////////")
   print("//              dRunner Setup               //")
   print("//////////////////////////////////////////////")

   dockerrun("mount_setup")

   local gitCommands = dockerrun("setup_git")
   for line in string.gmatch(gitCommands, "[^\n]+") do
      drun(table.unpack(splitString(line)))
   end

   print("")
   print("Setup succeded")
end

function mount()
   local mountCommands = dockerrun_output("mount_local", os.getenv("HOME"))
   for line in string.gmatch(mountCommands, "[^\n]+") do
      drun(table.unpack(splitString(line)))
   end
end

function help()
   return [[
   NAME
      ${SERVICENAME} - Runs minecraft

   SYNOPSIS
      ${SERVICENAME} help             - This help
      ${SERVICENAME} create PROJECT_NAME [PROJECT_PATH]
                                      - Creates a template dService project in PROJECT_PATH.
                                             If no path is supplied, the project will be created in PROJECT_NAME.
      ${SERVICENAME} setup            - Run the configuration wizard.
      ${SERVICENAME} mount            - Mount host machine to this VM over samba.
              
   DESCRIPTION
      Built from ${IMAGENAME}.
   ]]
end
