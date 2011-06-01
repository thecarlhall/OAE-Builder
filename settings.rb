nakamura = [{"path" => "../sparsemapcontent", "remote" => "nyuatlas@github", "repository" => "git@github.com:nyuatlas/sparsemapcontent.git"},
  {"path" => "../nakamura-solr", "remote" => "nyuatlas@github", "repository" => "git@github.com:nyuatlas/solr.git"},
  {"path" => "../nakamura", "remote" => "nyuatlas@github", "repository" => "git@github.com:nyuatlas/nakamura.git"}]
ui = {"path" => "../3akai-ux", "remote" => "nyuatlas@github", "repository" => "git@github.com:nyuatlas/3akai-ux.git"}

APP_OPTS = "-p 8181" 
JAVA_DEBUG_OPTS = "-Xdebug -Xrunjdwp:transport=dt_socket,address=8600,server=y,suspend=n"
MVN_OPTS = "-Dmaven.repo.local=/home/chall/projects/nyu/repository"
