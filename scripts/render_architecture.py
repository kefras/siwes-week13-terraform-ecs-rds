"""Create editable SVG and print-resolution PNG. No AWS API calls."""
from pathlib import Path
from html import escape
import base64
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/assets'
ICONS = OUT / 'aws'
ICONS.mkdir(parents=True, exist_ok=True)
paths = {
 'users':'General/Users.png',
 'igw':'NetworkingContentDelivery/VPCInternetGateway.png',
 'alb':'NetworkingContentDelivery/ElasticLoadBalancingApplicationLoadBalancer.png',
 'fargate':'Containers/Fargate.png',
 'rds':'Database/RDS.png',
 'ecr':'Containers/ElasticContainerRegistry.png',
 'secrets':'SecurityIdentityCompliance/SecretsManager.png',
 'logs':'ManagementGovernance/CloudWatch.png',
 's3':'Storage/SimpleStorageService.png'
}
for key, relative in paths.items():
 target=ICONS/(key+'.png')
 if not target.exists():
  urllib.request.urlretrieve('https://raw.githubusercontent.com/awslabs/aws-icons-for-plantuml/main/dist/'+relative,target)
(ICONS/'NOTICE.md').write_text('# AWS architecture icons\n\nSource: [AWS Labs AWS Icons for PlantUML](https://github.com/awslabs/aws-icons-for-plantuml), distributed from AWS architecture icons. Icons are used without recoloring. AWS trademarks belong to Amazon Web Services. See [AWS usage guidance](https://aws.amazon.com/architecture/icons/) and the [upstream license](https://github.com/awslabs/aws-icons-for-plantuml/blob/main/LICENSE).\n\n'+'\n'.join('- '+k+': `dist/'+v+'`' for k,v in paths.items())+'\n',encoding='utf-8')
svg=['''<svg xmlns="http://www.w3.org/2000/svg" width="2000" height="1480" viewBox="0 0 2000 1480" role="img" aria-labelledby="title desc">
<title id="title">Week 13 - ECS Fargate and private RDS</title>
<desc id="desc">An HTTP ALB spans two public subnets and routes to private FastAPI tasks. Tasks query private Multi-AZ MySQL over verified TLS. Private endpoints provide AWS service connectivity. CI and remote state are not deployed.</desc>
<defs>
<marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 Z" fill="#334155"/></marker>
<marker id="service-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 Z" fill="#64748b"/></marker>
<style>text{font-family:'Segoe UI',Arial,sans-serif;fill:#172b40}.line{fill:none;stroke:#334155;stroke-width:2.3;stroke-linejoin:round;marker-end:url(#arrow)}.support{fill:none;stroke:#64748b;stroke-width:1.9;stroke-dasharray:7 5;stroke-linejoin:round;marker-end:url(#service-arrow)}</style>
</defs><rect width="2000" height="1480" fill="white"/>''']
def text(x,y,value,size=20,weight=400,anchor='start',color=None):
 svg.append(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}"'+(f' style="fill:{color}"' if color else '')+'>'+escape(value)+'</text>')
def rect(x,y,w,h,stroke='#b9c5d0',fill='white',dash=None,width=1.5):
 svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
def icon(key,x,y,size=64):
 data=base64.b64encode((ICONS/(key+'.png')).read_bytes()).decode()
 svg.append(f'<image x="{x}" y="{y}" width="{size}" height="{size}" href="data:image/png;base64,{data}"/>')
def line(points,support=False,arrow=True):
 cls='support' if support else 'line'
 style='' if arrow else ' style="marker-end:none"'
 svg.append(f'<path class="{cls}" d="{points}"{style}/>')

text(60,62,'Week 13 | ECS Fargate + RDS',36,600)
text(60,103,'SIWES  •  Container application architecture  •  us-east-1',21,color='#536477')
text(1940,63,'DEPLOYED ARCHITECTURE',17,600,'end','#536477')
svg.append('<line x1="60" y1="128" x2="1940" y2="128" stroke="#d6dee6"/>')
rect(280,165,1660,1170,'#5f6b79',width=1.7)
text(305,200,'AWS Cloud  /  US East (N. Virginia)',21,600)
rect(320,240,1180,1055,'#448350',fill='#fcfefc',width=1.8)
text(345,276,'VPC',21,600,color='#27613a')
text(403,276,'vpc-08cb55538e782f57c',17,color='#536477')
rect(390,320,1060,205,'#8aaf89',fill='#f4faf3')
text(410,350,'PUBLIC SUBNET TIER',16,600,color='#436b43')
text(430,381,'Availability Zone a',19,600)
text(430,406,'subnet-041b38a966c203677',15,color='#536477')
text(1130,381,'Availability Zone b',19,600)
text(1130,406,'subnet-0a0c5a8493b2f0e05',15,color='#536477')
svg.append('<rect x="280" y="390" width="90" height="126" fill="white"/>')
icon('users',90,385,72)
text(126,492,'Users',20,600,'middle')
line('M174 420 H295')
text(226,400,'HTTP :80',17,anchor='middle')
icon('igw',295,393,56)
text(321,475,'Internet',16,anchor='middle')
text(321,496,'gateway',16,anchor='middle')
line('M352 420 H872')
icon('alb',880,372,76)
text(918,480,'Application Load Balancer',21,600,'middle')
text(918,507,'Internet-facing  •  HTTP listener :80',17,anchor='middle',color='#536477')
text(1120,552,'IP targets  •  HTTP :8000  •  GET /health',18,anchor='middle')
rect(390,615,1060,345,'#9aa8b5',fill='none',dash='6 4')
rect(410,650,480,265,'#6f9fc8',fill='#f3f8fc')
rect(950,650,480,265,'#6f9fc8',fill='#f3f8fc')
text(430,678,'PRIVATE SUBNET  /  AZ a',16,600,color='#345b7c')
text(430,701,'subnet-0982d8fffa95c1dd5',15,color='#536477')
text(970,678,'PRIVATE SUBNET  /  AZ b',16,600,color='#345b7c')
text(970,701,'subnet-0e2eaf1cd6e2a5882',15,color='#536477')
for x in (455,995):
 rect(x,728,390,130,'#b8c7d4')
 icon('fargate',x+20,757,62)
 text(x+104,766,'AWS Fargate task',21,600)
 text(x+104,796,'FastAPI  •  port 8000',18)
 text(x+104,826,'Private IP  •  image v2',17,color='#536477')
line('M918 525 V575 H780 V728')
line('M918 575 H1320 V728')
text(410,638,'ECS cluster / service: week13-ecs-app',18,600)
text(918,944,'Desired 2  •  CPU target 70%  •  Scale 2–4',17,anchor='middle',color='#536477')
text(918,991,'MySQL / TLS :3306  •  SELECT 1',18,anchor='middle')
rect(570,1018,640,140,'#8e9dc2',fill='#f7f8fc')
icon('rds',600,1052,70)
text(701,1063,'Amazon RDS for MySQL',23,600)
text(701,1096,'Private  •  Multi-AZ  •  appdb',19)
text(701,1126,'Single writer endpoint  •  verified TLS',17,color='#536477')
line('M650 858 V1018')
line('M1180 858 V1018')
rect(430,1200,1000,82,'#a8b3be',fill='white')
text(450,1226,'PRIVATE AWS SERVICE CONNECTIVITY  /  HTTPS :443',16,600)
text(450,1250,'Interface endpoints: ECR API, ECR Docker, Secrets Manager, Logs  •  one ENI per service in each AZ',15)
text(450,1272,'Existing S3 gateway endpoint: ECR image layers  •  no NAT internet route',15,color='#536477')
line('M455 793 H370 V1175 H475 V1200',True)
line('M1385 793 H1470 V1175 H1385 V1200',True)
text(1570,277,'AWS MANAGED SERVICES',17,600,color='#536477')
for y,key,title,sub,detail in [
 (320,'ecr','Amazon ECR','week13-ecs-app:v2','Original v1 preserved'),
 (550,'secrets','AWS Secrets Manager','RDS-managed credentials','username / password keys'),
 (780,'logs','Amazon CloudWatch','/ecs/week13-ecs-app','Log retention: 7 days'),
 (1010,'s3','Amazon S3','ECR image layers','Via S3 gateway endpoint')]:
 rect(1570,y,330,152,'#bdc7d1')
 icon(key,1590,y+24,57)
 text(1663,y+45,title,19,600)
 text(1663,y+79,sub,16)
 text(1663,y+112,detail,15,color='#536477')
 line(f'M1535 {y+76} H1570',True)
line('M1430 1236 H1535 V396',True,False)
text(60,1384,'Execution role: image pulls, secret retrieval and logs. Task role: no application AWS API permissions.',17,color='#536477')
text(60,1415,'HTTP-only lab endpoint  •  Local Terraform state  •  CI/CD deployment disabled',17,color='#536477')
text(60,1451,'Placement shown across configured AZs; current task placement and RDS writer AZ must be verified from runtime metadata.',15,color='#657487')
line('M1415 1380 H1480')
text(1495,1386,'Application / database traffic',16)
line('M1415 1414 H1480',True)
text(1495,1420,'Private AWS service traffic',16)
svg.append('</svg>')
(OUT/'week13-architecture.svg').write_text('\n'.join(svg),encoding='utf-8')
node="const fs=require('fs');const {createRequire}=require('module');const path=require('path');const req=createRequire(path.resolve('evidence/diagram-tools/package.json'));const {Resvg}=req('@resvg/resvg-js');const svg=fs.readFileSync('docs/assets/week13-architecture.svg','utf8');const r=new Resvg(svg,{fitTo:{mode:'width',value:4000},font:{loadSystemFonts:true,defaultFontFamily:'Segoe UI'}});fs.writeFileSync('docs/assets/week13-architecture.png',r.render().asPng());"
subprocess.run(['node','-e',node],cwd=ROOT,check=True)
print('Rendered editable SVG and 4000 x 2960 PNG in docs/assets')
