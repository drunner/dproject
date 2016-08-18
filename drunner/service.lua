-- drunner service configuration for helloworld

function drunner_setup()
-- addvolume(NAME, [BACKUP], [EXTERNAL])
   addvolume("drunner-${SERVICENAME}-config")

-- addcontainer(NAME)
   addcontainer("drunner/dproject")  -- First one must always be this container.
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

function dockerrun(terminal, command) {
   drun("docker", "run", terminal, "--name=\"dproject-"..command.."\"", "-h", "${HOSTNAME}", "-v", "drunner-${SERVICENAME}-config:/config", "drunner/dproject", command)
}

function create(...)
   local projectName = arg[0]
   local projectPath = projectName
   if arg[n] > 1 then
      projectPath = arg[1]
   end

   -- Create project directory
   os.execute("mkdir -p "..projectPath)

   -- allow the container to write into this folder.
   os.execute("chmod 0777 "..projectPath)

   -- get user id
   local userId = os.execute("id -u")

   -- get group id
   local groupId = os.execute("id -g")

   -- Copy out project files
   drun("docker", "run", "--rm", "-it", "--user=\""..userId..":"..groupId.."\"",
         "-v", projectPath..":/tempcopy", "drunner/dproject", "/bin/bash -c \"cp -r /project/. /tempcopy/\"")
   
   -- Replace <<PROJECT_NAME>> with $PROJECT_NAME
   os.execute("grep -rl \"<<PROJECT_NAME>>\" "..projectPath.." | xargs sed -i \"s/<<PROJECT_NAME>>/"..projectName.."/g\"")

   -- Set permissions on new files
   chownpath(projectPath, "chown -R $EUID:${GROUPS[0]} /s && chmod -R 0644 /s")

   print("Project \""..projectName.."\" has been created in \""..projectPath.."\"!")
   print("Create a Git repository and branch to start development:")
   print("   cd "..projectPath)
   print("   git init")
   print("   git add .")
   print("   git commit -m \"Project created\"")
   print("   git checkout -b dev")
   print("")
   print("You now have a Git repository on a dev branch to begin developing!")
end

function setup()

   if os.execute("dpkg -l | grep cifs-utils | wc -l") == 0 then
      print("Installing cifs-utils...")
      os.execute("sudo apt-get update && sudo apt-get install -y cifs-utils")
      print("Finished installing cifs-utils, resuming setup")
      print("")
   end

   print("//////////////////////////////////////////////")
   print("//              dRunner Setup               //")
   print("//////////////////////////////////////////////")

   COMMANDOPTS=("-it")
   dockerrun("-it", "mount_setup")
   os.execute(dockerrun("-it", "setup_git"))
   print("")
   print("Setup succeded")
   ;;
end

function mount()
   os.execute(dockerrun("-i", "mount_local"))
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
  