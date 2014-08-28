xml.boletin do
	xml.id id
	xml.fecha fecha
		
	listas.each do |a|
		pos=1
		a.each do |n|

			if (n =~ /Reflex (\d+)/) || n.empty?
				n="Reflexion #{pos}"
			end
			
			f=File.open('./hop.log','a')
			f.puts(n)
			f.close
			
			h=Digest::MD5.hexdigest(n)
			i=items[h]	

			if lan=='es'
				titulo=i.titulo
				texto=i.texto
				link=i.enlace
			else
				titulo=i.title
				texto=i.text
				link=i.link
			end	

			xml.item do
				xml.titulo titulo
				xml.texto texto
				xml.link link
				xml.tipo i.tipo
				xml.tag i.tags
				xml.pos pos
			end
			pos+=1
		end
	end


end


