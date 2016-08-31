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

function dockerrun(command)
   return drun("docker", "run", "-i", "--rm", "--name=dproject-"..command, "-v", "drunner-${SERVICENAME}-config:/config", "${IMAGENAME}", command)
end

function dockerrun_output(command)
   return drun_output("docker", "run", "-i", "--rm", "--name=dproject-"..command, "-v", "drunner-${SERVICENAME}-config:/config", "${IMAGENAME}", command)
end

function dockerrun_outputandarg(command, argument)
   return drun_output("docker", "run", "-i", "--rm", "--name=dproject-"..command, "-v", "drunner-${SERVICENAME}-config:/config", "${IMAGENAME}", command, argument)
end

function create(...)
   local args = table.pack(...)
   local projectName = args[1]
   local projectPath = projectName
   if args.n > 1 then
      projectPath = args[2]
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

   local gitCommands = dockerrun_output("setup_git")
   for line in string.gmatch(gitCommands, "[^\n]+") do
      drun(dsplit(line))
   end

   print("")
   print("Setup succeded")
end

function mount()
   local mountCommands = dockerrun_outputandarg("mount_local", os.getenv("HOME"))
   for line in string.gmatch(mountCommands, "[^\n]+") do
      drun(dsplit(line))
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
