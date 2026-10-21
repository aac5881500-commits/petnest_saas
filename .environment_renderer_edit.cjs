const fs=require('fs');
const path='lib/features/shop/widgets/environment/environment_intro_view.dart';
let s=fs.readFileSync(path,'utf8').replace(/\r\n/g,'\n');
function rep(a,b){if(s.split(a).length!==2)throw Error(a.slice(0,60));s=s.replace(a,b);}
rep("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:petnest_saas/core/models/environment_presentation.dart';\nimport 'environment_service_section.dart';");
rep('    this.scrollController,','    this.scrollController,\n    this.presentation,\n    this.sectionKeys,');
rep('  final EnvironmentIntroStyle style;', '  final EnvironmentPresentation? presentation;\n  final Map<String, GlobalKey>? sectionKeys;\n  final EnvironmentIntroStyle style;');
const a=s.indexOf('        if (_showHero)'),b=s.lastIndexOf('\n      ],\n    );');
if(a<0||b<a)throw Error('sections');
let body=s.slice(a,b);
const markers=['        if (_showHero)','        if (features.isNotEmpty)','        if (_showBanner)','        if (careItems.isNotEmpty)','        if (bottomNote.trim()','        if (galleryImages.isNotEmpty)'];
const ids=['hero','features','banner','care','note','gallery'];
const starts=markers.map(x=>body.indexOf(x));
if(starts.some(x=>x<0))throw Error('markers');
const parts=starts.map((x,i)=>body.slice(x,starts[i+1]??body.length));
parts[1]=parts[1].replace("...features.map((Map<String, dynamic> item) {", "...features.asMap().entries.map((entry) {\n            final item = entry.value;")
 .replace("reverse: item['layout'] == 'imageLeft',", "reverse: p.preset == 'warm' ? entry.key.isOdd : item['layout'] == 'imageLeft',\n              minimal: p.preset == 'minimal',");
parts[3]=parts[3].replace('if (careItems.isNotEmpty)', 'if (!modern && careItems.isNotEmpty)');
parts[3]+=`\n        if (modern && (careItems.isNotEmpty || p.services.any((s) => s.visible))) ...[
          SizedBox(height: style.sectionGap),
          EnvironmentServiceSection(presentation:p, items:careItems, theme:theme,style:style,
            iconOf:featureIconOf,imageBuilder:imageBuilder),
        ],\n`;
const replacement=`    final p = presentation ?? EnvironmentPresentation();
    final modern = p.toMap().isNotEmpty;
    final sections = <String,List<Widget>>{\n${parts.map((part,i)=>`      '${ids[i]}': [\n${part}\n      ],`).join('\n')}
    };
    final order = switch(p.preset) {
      'care' => ['hero','care','features','banner','gallery','note'],
      'photo' => ['hero','gallery','features','banner','care','note'],
      'warm' || 'minimal' => ['hero','features','banner','care','gallery','note'],
      _ => ['hero','features','banner','care','note','gallery'],
    };
    return Align(alignment:Alignment.topCenter,child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:1200),
      child: ListView(controller:scrollController,
        padding:EdgeInsets.only(bottom:style.sectionGap+8),
        children:[for(final id in order) if(sections[id]!.isNotEmpty)
          Column(key:sectionKeys?[id], crossAxisAlignment:CrossAxisAlignment.stretch,children:sections[id]!),
        ],
      ),
    ));`;
const buildstart=s.indexOf('    return ListView(');
s=s.slice(0,buildstart)+replacement+'\n  }\n}\n';
fs.writeFileSync(path,s);
