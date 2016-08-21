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

function dockerrun(terminal, command) 
   return drun_output("docker", "run", terminal, "--rm", "--name=dproject-"..command, "-v", "drunner-${SERVICENAME}-config:/config", "drunner/dproject", command)
end

function create(...)
   local projectName = arg[0]
   local projectPath = projectName
   if arg[n] > 1 then
      projectPath = arg[1]
   end

   -- Create project directory
   drun("mkdir -p "..projectPath)

   -- allow the container to write into this folder.
   drun("chmod 0777 "..projectPath)

   -- get user id
   local userId = drun_output("id -u")

   -- get group id
   local groupId = drun_output("id -g")

   -- Copy out project files
   drun("docker", "run", "--rm", "-it", "--user=\""..userId..":"..groupId.."\"",
         "-v", projectPath..":/tempcopy", "drunner/dproject", "/bin/bash -c \"cp -r /project/. /tempcopy/\"")
   
   -- Replace <<PROJECT_NAME>> with $PROJECT_NAME
   drun("grep -rl \"<<PROJECT_NAME>>\" "..projectPath.." | xargs sed -i \"s/<<PROJECT_NAME>>/"..projectName.."/g\"")

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

function wizard()

   if drun_output("dpkg -l | grep cifs-utils | wc -l") == 0 then
      print("Installing cifs-utils...")
      drun("sudo apt-get update && sudo apt-get install -y cifs-utils")
      print("Finished installing cifs-utils, resuming wizard")
      print("")
   end

   print("//////////////////////////////////////////////")
   print("//              dRunner Wizard              //")
   print("//////////////////////////////////////////////")

   dockerrun("-it", "mount_setup")
   drun(dockerrun("-it", "setup_git"))
   print("")
   print("Wizard succeded")
   ;;
end

function mount()
   drun("bash -c \""..dockerrun("-i", "mount_local").."\"")
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
      ${SERVICENAME} wizard            - Run the configuration wizard.
      ${SERVICENAME} mount            - Mount host machine to this VM over samba.

   DESCRIPTION
      Built from ${IMAGENAME}.
   ]]
end
  