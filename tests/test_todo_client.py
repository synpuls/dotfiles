"""Remote-only wrapper checks. Set TODO_TEST_REPO for the real atomic installer check."""
import os
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
repo=Path(os.environ.get('TODO_TEST_REPO', root.parent/'todo_manager'))
wrapper=root/'shared/bin/todo'
with tempfile.TemporaryDirectory(prefix='todo client ') as d:
 p=Path(d).resolve(); prefix=p/'client'; env=dict(os.environ, HOME=str(p), XDG_CONFIG_HOME=str(p/'config'))
 if (repo/'build/todo').is_file():
  result=subprocess.run([str(repo/'scripts/install-client'),'--from',str(repo/'build/todo'),'--prefix',str(prefix)],env=env,capture_output=True)
  assert result.returncode==0, result.stderr
  old=(prefix/'bin/todo').resolve()
  broken=p/'broken';broken.write_text('#!/bin/sh\nexit 12\n');broken.chmod(0o755)
  result=subprocess.run([str(repo/'scripts/install-client'),'--from',str(broken),'--prefix',str(prefix)],env=env,capture_output=True)
  assert result.returncode!=0 and (prefix/'bin/todo').resolve()==old
 stub=p/'probe';stub.write_text('#!/usr/bin/env python3\nimport os,sys,json\nprint(json.dumps({"args":sys.argv[1:],"input":sys.stdin.read(),"cwd":os.getcwd(),"token_set":len(os.environ.get("TODO_TOKEN",""))>=32}))\nsys.exit(7)\n');stub.chmod(0o755)
 env['TODO_CLI_BINARY']=str(stub);env.pop('TODO_TOKEN',None)
 result=subprocess.run([str(wrapper),'mcp'],cwd=p,env=env,input='message',text=True,capture_output=True)
 assert result.returncode==1 and not result.stdout
 token=p/'config/todo-manager/token';token.parent.mkdir(parents=True);token.write_text('x'*48);token.chmod(0o644)
 result=subprocess.run([str(wrapper),'mcp'],cwd=p,env=env,input='message',text=True,capture_output=True)
 assert result.returncode==1 and not result.stdout
 token.chmod(0o600)
 result=subprocess.run([str(wrapper),'mcp'],cwd=p,env=env,input='message',text=True,capture_output=True)
 import json
 data=json.loads(result.stdout)
 assert result.returncode==7 and data['args']==['--remote','https://todo.home.synpuls.digital','mcp'] and data['input']=='message' and data['cwd']==str(p) and data['token_set']
print('PASS atomic client install, failed update preservation, missing/insecure token rejection, remote-only stdio/args/cwd/exit')
