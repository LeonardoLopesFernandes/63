import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class CelularSpec {
  final String id;
  final String marca;
  final String modelo;
  final String armazenamento;
  final List<String> specs;
  CelularSpec({required this.id, required this.marca, required this.modelo, required this.armazenamento, required this.specs});
  factory CelularSpec.fromJson(Map<String,dynamic>json){return CelularSpec(id:(json['id']??'').toString(),marca:(json['marca']??'').toString(),modelo:(json['modelo']??'').toString(),armazenamento:(json['armazenamento']??'').toString(),specs:(json['specs']as List?)?.map((e)=>e.toString()).toList()??[]);}  Map<String,dynamic> toJson()=>{'id':id,'marca':marca,'modelo':modelo,'armazenamento':armazenamento,'specs':specs};}

class PapeletaData{final String modelo;final String armazenamento;final List<String> specs;final String precoOriginal;final String desconto;final String precoComDesconto;final int qtdParcelas;final String valorParcela;final String ean;final String codSap;final bool daSemana;PapeletaData({required this.modelo,required this.armazenamento,required this.specs,required this.precoOriginal,required this.desconto,required this.precoComDesconto,required this.qtdParcelas,required this.valorParcela,this.ean='',this.codSap='',this.daSemana=false,});}

class PapeletaFormState{CelularSpec? selectedPhone;String priceText;String discountText;String ean;String codSap;bool daSemana;PapeletaFormState({this.selectedPhone,this.priceText='',this.discountText='',this.ean='',this.codSap='',this.daSemana=false,});PapeletaFormState copyWith({CelularSpec? selectedPhone,String? priceText,String? discountText,String? ean,String? codSap,bool? daSemana,})=>PapeletaFormState(selectedPhone:selectedPhone??this.selectedPhone,priceText:priceText??this.priceText,discountText:discountText??this.discountText,ean:ean??this.ean,codSap:codSap??this.codSap,daSemana:daSemana??this.daSemana);} 

Future<List<CelularSpec>>loadCelulares() async{try{final str=await rootBundle.loadString('assets/celulares.json');final list=json.decode(str)as List;return list.map((e)=>CelularSpec.fromJson(e as Map<String,dynamic>)).toList();}catch(_){return [];}}

CelularSpec? findPhoneByDescription(List<CelularSpec>celulares,String description){final desc=description.toLowerCase().trim();CelularSpec? best;var bestScore=0;for(final phone in celulares){final searchStr='${phone.marca} ${phone.modelo} ${phone.armazenamento}'.toLowerCase();final words=searchStr.split(' ').where((w)=>w.length>1);final score=words.where((w)=>desc.contains(w)).length;if(score>bestScore){bestScore=score;best=phone;}}return bestScore>=1?best:null;}

Future<List<CelularSpec>>loadSavedPhones() async{final dir=await getApplicationDocumentsDirectory();final file=File('${dir.path}/phones.json');if(!await file.exists())return [];final str=await file.readAsString();final list=json.decode(str)as List;return list.map((e)=>CelularSpec.fromJson(e as Map<String,dynamic>)).toList();}
Future<void>addSavedPhone(CelularSpec phone) async{final phones=await loadSavedPhones();phones.add(phone);final dir=await getApplicationDocumentsDirectory();final file=File('${dir.path}/phones.json');await file.writeAsString(json.encode(phones.map((p)=>p.toJson()).toList()));}
Future<CelularSpec?>fetchSpecsFromApi(String description) async{final query=Uri.encodeComponent(description);final url='https://api.mobileapi.dev/v1/devices?search=$query';try{final resp=await http.get(Uri.parse(url));if(resp.statusCode==200){final data=json.decode(resp.body);if(data['results']is List){final devs=data['results']as List;if(devs.isNotEmpty){final dev=devs[0]as Map<String,dynamic>;final specs=<String>[];if(dev['camera_front']!=null){specs.add("Câmera frontal ${dev['camera_front']}MP");}if(dev['camera_back']!=null){specs.add('Câmera traseira ${dev['camera_back']}MP');}if(dev['ram']!=null){specs.add('RAM ${dev['ram']}GB');}if(dev['battery']!=null){specs.add('Bateria ${dev['battery']}mAh');}if(dev['processor']!=null){specs.add('Processador ${dev['processor']}');}return CelularSpec(id:dev['id']?.toString()??DateTime.now().millisecondsSinceEpoch.toString(),marca:dev['brand']?.toString()??'',modelo:dev['model']?.toString()??description,armazenamento:dev['storage']?.toString()??'Unknown',specs:specs);} } } }catch(_){ }return null;}
Future<CelularSpec?>getOrCreateSpecs(String description,List<CelularSpec>baseList) async{final local=findPhoneByDescription(baseList,description);if(local!=null)return local;final saved=await loadSavedPhones();final localSaved=findPhoneByDescription(saved,description);if(localSaved!=null)return localSaved;final fetched=await fetchSpecsFromApi(description);if(fetched==null)return null;await addSavedPhone(fetched);return fetched;}

String parsePriceToDigits(String price){final lastDot=price.lastIndexOf('.');final lastComma=price.lastIndexOf(',');final decIdx=lastDot>lastComma?lastDot:lastComma;if(decIdx>=0){final intPart=price.substring(0,decIdx).replaceAll(RegExp(r'[^0-9]'),'');var decPart=price.substring(decIdx+1).replaceAll(RegExp(r'[^0-9]'),'');decPart=decPart.padRight(2,'0').substring(0,2);return intPart+decPart;}return price.replaceAll(RegExp(r'[^0-9]'),'')+'00';}
