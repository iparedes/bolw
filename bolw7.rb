require 'sinatra'
require 'nokogiri'
require 'pry'
require 'digest/md5'
require 'fileutils'

require_relative 'item'

use Rack::Auth::Basic, "Restricted Area" do |username, password|
	F='creds'

	if File.exist?(F)
		creds={}
		File.open('./creds') do |fp|
			fp.each do |line|
				nombre,pass = line.chomp.split(":")
				creds[nombre]=pass
			end
		end

		creds[username]==password
	else
		abort("Falta el archivo de credenciales")
	end
end

set :bind, '0.0.0.0'
set :port, 1212
set :items, Hash.new
set :currentitem, nil
set :docen, ''
set :doces, ''
set :boletin, ''
set :idboletin, ''
set :fechaes, ''
set :fechaen, ''
set :tags, nil
set	:noticias, Array.new
set	:documentos, Array.new
set	:eventos, Array.new
set	:reflexiones, Array.new
set :notsel, nil
set :docsel, nil
set :evesel, nil
set :refsel, nil
set :DirHTML, './public/html/'
set :DirXML, './public/xml/'
set :downlist, Array.new
set :erro, ''
set :cargado, false

Meses=['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre']
Months=['January','February','March','April','May','June','July','August','September','October','November','December']

def genXML(fname,idioma)
		f=File.open(fname,'w')
		if idioma=='en'
			f.write("#{builder :xml, :locals => {:items => settings.items, :id => settings.idboletin, :fecha => settings.fechaen, :listas => [settings.noticias,settings.documentos,settings.eventos,settings.reflexiones] , :lan =>'en'}}")
		else
			f.write("#{builder :xml, :locals => {:items => settings.items, :id => settings.idboletin, :fecha => settings.fechaes, :listas => [settings.noticias,settings.documentos,settings.eventos,settings.reflexiones], :lan =>'es'}}")
		end
		f.close()
end

def genHTML(fname,idioma)
	f=File.open(fname,'w')
	if idioma=='en'
		f.write("#{erb :html, :locals => {:items => settings.items, :id => settings.idboletin, :fecha => settings.fechaen, :listas => [settings.noticias,settings.documentos,settings.eventos,settings.reflexiones] , :lan =>'en'}}")
	else
		f.write("#{erb :html, :locals => {:items => settings.items, :id => settings.idboletin, :fecha => settings.fechaes, :listas => [settings.noticias,settings.documentos,settings.eventos,settings.reflexiones] , :lan =>'es'}}")
	end
	f.close
end

def htmlitem(item,lan)
	if (lan=='es')
		tit=item.titulo
		tex=item.texto
		lin=item.enlace
	else
		tit=item.title
		tex=item.text
		lin=item.link
	end
	t="<div>
    <strong>#{tit}</strong></div>
<div>#{tex}</div>"
	if (lan=='es')
		u="<div><a href=\"#{lin}\" target=\"_self\">Enlace</a></div><div>&nbsp;</div>"
	else
		u="<div><a href=\"#{lin}\" target=\"_self\">Link</a></div><div>&nbsp;</div>"
	end
	return t+u
end


def diff(lv,ln)
	if lv.empty?
		ln
	else
		nuevos=ln-lv
		aux=lv+nuevos
		fueras=lv-ln
		aux=aux-fueras
		aux
	end
end

def up(lista,i)
	if (i>0)
		a=lista[i-1]
		lista[i-1]=lista[i]
		lista[i]=a
	end
	lista
end

def down(lista,i)
	if (i<lista.length-1)
		a=lista[i+1]
		lista[i+1]=lista[i]
		lista[i]=a
	end
	lista
end

def carga_tags
	filenames=Dir[settings.DirXML+"*-en.xml"]
	tags=Array.new
	filenames.each do |n|
		f=File.open(n,'r')
		doc=Nokogiri::XML(f)
		stags=doc.xpath("//tag")
		stags.each do |s|
			ta=s.text.split(',')
			ta.each do |t|
				tags.push(t)
			end
		end
		f.close
	end
	settings.tags=Array.new
	settings.tags=tags.sort.uniq
end

def carga_boletin
	fname=settings.DirXML+"#{settings.boletin}-en.xml"

	f=File.open(fname)
	settings.docen=Nokogiri::XML(f)
	f.close
	fname=settings.DirXML+"#{settings.boletin}.xml"
	f=File.open(fname)
	settings.doces=Nokogiri::XML(f)
	f.close
	
	settings.idboletin=settings.doces.xpath("//id").text
	settings.fechaes=settings.doces.xpath("//fecha").text
	settings.fechaen=settings.docen.xpath("//fecha").text

	nodoses=settings.doces.xpath("//item")
	nodosen=settings.docen.xpath("//item")

	nodos=nodoses.zip(nodosen)

	its=Hash.new

	nodos.each do |nodoes,nodoen|
		item=Item.new()
		item.setfromxml(nodoes,nodoen)
		h=Digest::MD5.hexdigest(item.title)
		its[h]=item
		#settings.items.push(item)
	end
	# items contiene los items cargados de los XML es y en
	its
end

def titulo_repetido(title)
	lista=[settings.noticias,settings.eventos,settings.documentos]
	retval=false
	lista.each do |l|
		if l.include?(title)
			retval=true
			break
		end
	end
	retval
end

get '/' do
	erb :index
end

get '/cargaboletin' do
	carga_tags
	settings.noticias=Array.new
	settings.documentos=Array.new
	settings.eventos=Array.new
	settings.reflexiones=Array.new
	erb :cargaboletin
end

post '/cargaboletin' do
	settings.boletin=params[:boletin]

	settings.items=carga_boletin

	redirect '/item'
end


get '/item' do
	erb :item, :locals => {:items => settings.items}
end

post '/item' do

	case (params[:action])
	when 'OK'
		titulo=params[:titulo]
		title=params[:title]
		texto=params[:texto]
		text=params[:text]	
		enlace=params[:enlace]	
		link=params[:link]	
		tipo=params[:tipo]
		tags=params[:tags]
		
		if (tipo!='reflexion')
			if link.empty?
				link=enlace
			end
			if enlace.empty?
				enlace=link
			end
		end

		if settings.cargado
			# Estamos editando
			# CurrentItem se establecio al cargar
			if settings.currentitem.title != title

				# ha cambiado el title, por tanto hay que actualizar el hash
				h=Digest::MD5.hexdigest(settings.currentitem.title)
				i=Digest::MD5.hexdigest(title)

				# Busca los elementos del hash hasta encontrar el de la clave vieja
				# mientras genera un nuevo hash con el elemento modificado
				xxx=Hash[settings.items.map{ |k,v| (k==h ? [i,v]:[k,v])}]
				# Esta asignacion extraña es porque al reasignar el hash aparentemente
				# mantenia elementos anteriores :P
				#settings.items=Array.new
				settings.items=nil
				settings.items=xxx
				settings.currentitem.setall(titulo,title,texto,text,enlace,link,tipo,tags)
				#settings.items[i]=settings.currentitem
			else
				settings.currentitem=Item.new
				settings.currentitem.setall(titulo,title,texto,text,enlace,link,tipo,tags)
			end
			
			# Comprobaciones (redirigen a /item con currentitem establecido
			if (tipo!='reflexion')
				if (link.empty? && enlace.empty?)
					settings.erro="Debes completar el campo Enlace/Link"
					redirect '/item'
				end
			end

			# Si llega aqui termina normalmente
			# Metemos en la lista de items
			h=Digest::MD5.hexdigest(title)
			settings.items[h]=settings.currentitem
			# Anulamos currentitem antes de redirigir
			settings.currentitem=nil
			settings.cargado=false
			redirect '/item'
		
		else
			# Nuevo elemento
			
			settings.currentitem=Item.new
			settings.currentitem.setall(titulo,title,texto,text,enlace,link,tipo,tags)
			
			# Comprobaciones (redirigen a /item con currenitem establecido
			if (tipo!='reflexion')
				if (link.empty? && enlace.empty?)
					settings.erro="Debes completar el campo Enlace/Link"
					redirect '/item'
				end
			end
			if titulo_repetido(title)
				settings.erro="Titulo repetido"
				redirect '/item'			
			end
			
			# Metemos en la lista de items
			h=Digest::MD5.hexdigest(title)
			settings.items[h]=settings.currentitem
			# Anulamos currentitem antes de redirigir
			settings.currentitem=nil
			redirect '/item'
		end


		#======================================================================

=begin
		# mmmmm, si hago nil al final de item. Esto siempre es cierto (lo otro no)
		# tengo que ver claramente los flujos
		# nuevo elemento, editar elemento, editar titulo del elemento
		# teniendo en cuenta si hubo error
		if !settings.cargado
			# nuevo item
			item=Item.new
			item.setall(titulo,title,texto,text,enlace,link,tipo,tags)
			h=Digest::MD5.hexdigest(title)
			settings.items[h]=item
			
			settings.currentitem=Item.new
			settings.currentitem.setall(titulo,title,texto,text,enlace,link,tipo,tags)
			if titulo_repetido(title)
				settings.erro="Titulo repetido"
				redirect '/item'
			end
		else
		# editar item
			if settings.currentitem.titulo != title
				# ha cambiado el title, por tanto hay que actualizar el hash
				h=Digest::MD5.hexdigest(settings.currentitem.title)
				i=Digest::MD5.hexdigest(title)

				#map={ h => i }
				#settings.items=Hash[settings.items.map{ |k,v| map[k] || [k,v] }]
				# Busca los elementos del hash hasta encontrar el de la clave vieja
				# mientras genera un nuevo hash con el elemento modificado
				xxx=Hash[settings.items.map{ |k,v| (k==h ? [i,v]:[k,v])}]
				# Esta asignacion extraña es porque al reasignar el hash aparentemente
				# mantenia elementos anteriores :P
				settings.items=Array.new
				settings.items=xxx
				settings.currentitem.setall(titulo,title,texto,text,enlace,link,tipo,tags)
			end
		end
		settings.cargado=false
		
		if (tipo!='reflexion')
			if (link.empty? && enlace.empty?)
				settings.erro="Debes completar el campo Enlace/Link"
				h=Digest::MD5.hexdigest(settings.currentitem.title)
				settings.items.delete(h)
				redirect '/item'
			end
			
			lista=[settings.noticias,settings.eventos,settings.documentos]
			lista.each do |l|
				if l.include?(title)
					settings.erro="Titulo repetido"
					h=Digest::MD5.hexdigest(settings.currentitem.title)
					settings.items.delete(h)
					redirect '/item'
				end
			end
			
		end
		
		settings.currentitem=nil		
					
		redirect '/item'
=end
	when 'Carga'
		t=''
		if !params[:noticias].nil?
			t=params[:noticias]
		elsif !params[:documentos].nil?
			t=params[:documentos]
		elsif !params[:eventos].nil?
			t=params[:eventos]
		else !params[:reflexiones].nil?
			t=params[:reflexiones]
		end
		
		h=Digest::MD5.hexdigest(t)
		settings.currentitem=settings.items[h]
		settings.cargado=true
		redirect '/item'
	when 'Borra'
		t=params[:title]

		if (t)
			h=Digest::MD5.hexdigest(t)
			settings.items.delete(h)
			settings.currentitem=nil
		end
		redirect '/item'
		
	when 'Terminar'

		#fname=settings.DirXML+"#{settings.boletin}-en.xml"
		#genXML(fname,'en')	
		#fname=settings.DirXML+"#{settings.boletin}.xml"
		#genXML(fname,'es')
		
		settings.fechaen =~ /(\w+) (\d+)\, (\d+)/
		
		dia=$2.rjust(2,'0')
		mes=(Months.index($1)+1).to_s.rjust(2,'0')

		fecha=$3+mes+dia

		fnamees="Boletin-#{fecha}.html"
		genHTML(settings.DirHTML+fnamees,'es')

		fnameen="Boletin-#{fecha}-en.html"
		genHTML(settings.DirHTML+fnameen,'en')

		redirect '/descargahtml'
=begin		
		diri=Dir.pwd

		

		
		binding.pry
		File.delete(diri+settings.DirHTML+fnamees)
		File.delete(diri+settings.DirHTML+fnameen)
		
		Zip::File.open(zipname,Zip::File::CREATE) do |zipfile|
			archs.each do |fname|
				zipfile.add(fname,settings.DirHTML+fname)
			end
		end
	
		send_file(zipname, :filename => "boletin#{settings.idboletin}.zip", :disposition => 'inline', :type => 'Application/octet-stream')		

		diri=Dir.pwd
		binding.pry
		FileUtils.remove_file(diri+zipname)
=end
		"Terminado"
	when 'Copiar Elementos'
		redirect '/copiar'
	when 'notup'
		t=params[:noticias]
		i=settings.noticias.index(t)
		if (!i.nil?)
			settings.noticias=up(settings.noticias,i)
			i==0 ? settings.notsel=0 : settings.notsel=i-1
		end
		redirect '/item'
	when 'notdown'
		t=params[:noticias]
		i=settings.noticias.index(t)
		if (!i.nil?)
			settings.noticias=down(settings.noticias,i)
			i==settings.noticias.length-1 ? settings.notsel=i : settings.notsel=i+1
		end
		redirect '/item'
	when 'docup'
		t=params[:documentos]
		i=settings.documentos.index(t)
		if (!i.nil?)		
			settings.documentos=up(settings.documentos,i)
			i==0 ? settings.docsel=0 : settings.docsel=i-1
		end
		redirect '/item'
	when 'docdown'
		t=params[:documentos]
		i=settings.documentos.index(t)
		if (!i.nil?)		
			settings.documentos=down(settings.documentos,i)
			i==settings.documentos.length-1 ? settings.docsel=i : settings.docsel=i+1
		end
		redirect '/item'
	when 'eveup'
		t=params[:eventos]
		i=settings.eventos.index(t)
		if (!i.nil?)		
			settings.eventos=up(settings.eventos,i)
			i==0 ? settings.evesel=0 : settings.evesel=i-1
		end
		redirect '/item'
	when 'evedown'
		t=params[:eventos]
		i=settings.eventos.index(t)
		if (!i.nil?)		
			settings.eventos=down(settings.eventos,i)
			i==settings.eventos.length-1 ? settings.evesel=i : settings.evesel=i+1
		end
		redirect '/item'
	when 'refup'
		t=params[:reflexiones]
		i=settings.reflexiones.index(t)
		if (!i.nil?)				
			settings.reflexiones=up(settings.reflexiones,i)
			i==0 ? settings.refsel=0 : settings.refsel=i-1
		end
		redirect '/item'
	when 'refdown'
		t=params[:reflexiones]
		i=settings.reflexiones.index(t)
		if (!i.nil?)				
			settings.reflexiones=down(settings.reflexiones,i)
			i==settings.reflexiones.length-1 ? settings.refsel=i : settings.refsel=i+1
		end
		redirect '/item'
	end
end

get '/nuevoboletin' do
	erb :nuevoboletin
end

post '/nuevoboletin' do
	
	settings.idboletin=params[:id]
	settings.boletin="boletin"+params[:id]
	settings.fechaes=params[:dia]+" de "+Meses[params[:mes].to_i-1]+" de "+params[:ano]
	settings.fechaen=Months[params[:mes].to_i-1]+" "+params[:dia]+", "+params[:ano]
	
	redirect '/item'
end

get '/descargahtml' do
	erb :descargahtml
end

get '/descargaxml' do
	erb :descargaxml
end

get '/copiar' do
	erb :copiar
end

post '/copiar' do

	settings.boletin=params[:boletin]
	
	if (settings.boletin.nil?)
		settings.erro="Debes seleccionar un boletin de destino"
		redirect '/copiar'
	end
	
	settings.noticias=[]
	settings.documentos=[]
	settings.eventos=[]
	settings.reflexiones=[]
	
	origitems=settings.items.dup
	
	# Meh
	settings.items=nil
	settings.items={}
	settings.items=carga_boletin
	
	case (params[:action])
	when 'Copiar'
		
	listas=[params[:noticias],params[:documentos],params[:eventos],params[:reflexiones]]

		listas.each do |t|
			if !t.nil?
				t.each do |e|
					h=Digest::MD5.hexdigest(e)
					elem=origitems[h]
					settings.items[h]=elem
				end
			end
		end
	end
	redirect '/item'
end

get '/upload' do
	erb :upload
end

post '/upload' do
	fname=params[:myfile]

	if fname.length!=2
		settings.erro=("Debes seleccionar dos archivos")
		redirect '/upload'
	end
	f1=fname[0][:filename]
	f2=fname[1][:filename]
	f1 =~ /.+(\d+).+/
	n1=$1

	f2 =~ /.+(\d+).+/
	n2=$1
	if (n1!=n2)
		settings.erro=("Los XML deben pertenecer al mismo n&uacute;mero de bolet&iacute;n")
		redirect '/upload'
	end	
	xsd=Nokogiri::XML::Schema(File.read("./boletin.xsd"))

	
	fname.each do |fn|
		doc=Nokogiri::XML(File.read('./public/xml/'+fn[:filename]))
		a=xsd.validate(doc)
		if !a.empty?
			binding.pry
			t="#{fn[:filename]} Linea #{a[0].line}: #{a[0].message}"
			settings.erro=t
			redirect '/upload'
		end

		File.open('./public/xml/'+fn[:filename],"w") do |f|
			f.write(fn[:tempfile].read)
		end
	end
	redirect '/'
end

get '/download/:filename' do |filename|
  send_file "./public/html/#{filename}", :filename => filename, :type => 'Application/octet-stream'
end

