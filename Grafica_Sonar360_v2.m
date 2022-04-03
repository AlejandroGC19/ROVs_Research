function figura = Grafica_Sonar360_v2(distance,ganancia)

global exit_program
global restart
global stop
global play
global TimeText
global Peces
global cambiaGain
global cambiaDist
global ganancia
global distance

% Crea una figura, le establece nombre, posición, color y textos
figura=figure('name','Figura','menubar','none','Position', [769.8,41.8,766.4,789.6]);
title('INTENSIDAD DEL REBOTE');
axis ([-distance-distance/6 distance+distance/6 -distance-distance/6 distance+distance/6]);
axis off
colormap('jet');
colorbar('Ticks',[30,80,130,180,230,280],'TickLabels',{'Agua','Muy suave','Suave','Medio','Intenso','Muy intenso'});
hold on

text(0, distance+distance/20, '0', 'HorizontalAlignment', 'center');
text(distance/1.5+distance/10, distance/1.5+distance/10, '50', 'HorizontalAlignment', 'center');
text(distance+distance/12, 0, '100', 'HorizontalAlignment', 'center');
text(distance/1.5+distance/10, -(distance/1.5+distance/10), '150', 'HorizontalAlignment', 'center');
text(0, -(distance+distance/20), '200', 'HorizontalAlignment', 'center');
text(-(distance/1.5+distance/10), -(distance/1.5+distance/10), '250', 'HorizontalAlignment', 'center');
text(-(distance+distance/12), 0, '300', 'HorizontalAlignment', 'center');
text(-(distance/1.5+distance/10), distance/1.5+distance/10, '350', 'HorizontalAlignment', 'center');

text(-distance, distance+distance/10, 'Distancia:');
D=text(-distance/1.6, distance+distance/10, '0');
D.String=num2str(distance,'%u');
text(-distance/2.7, distance+distance/10, 'mm');
text(distance/6, distance+distance/10, 'Tiempo:');
TimeText=text(distance/2, distance+distance/10, '0.0');
text(distance/1.25, distance+distance/10, 'segundos');
text(-distance, -distance, 'Ganancia:');
G=text(-distance/1.6, -distance, '0');
G.String=num2str(ganancia,'%u');
text(-distance/2.5, -distance-distance/5, 'Cantidad de peces:');
Peces=text(distance/8, -distance-distance/5, '0');
text(-distance-distance/2.1, -distance*1.5+distance, 'Posiciones (mm)');
text(-distance-distance/2, -distance*1.6+distance, 'ID');
text(-distance-distance/3, -distance*1.6+distance, 'X');
text(-distance-distance/8, -distance*1.6+distance, 'Y');
drawnow;

% Crea botones y cuadros de texto interactivos dentro de la figura
bot(1)=uicontrol('parent',figura,'style','pushbutton','string','Play',...
    'position',[275 10 70 30],'callback',@iniciar,'fontsize',11);
bot(2)=uicontrol('parent',figura,'style','pushbutton','string','Stop',...
    'position',[350 10 70 30],'callback',@parar,'fontsize',11);
bot(3)=uicontrol('parent',figura,'style','pushbutton','string','Reinicio',...
    'position',[425 10 70 30],'callback',@reiniciar,'fontsize',11);
bot(4)=uicontrol('parent',figura,'style','pushbutton','string','Salir',...
    'position',[500 10 70 30],'callback',@salir,'fontsize',11);
bot(5)=uicontrol('parent',figura,'style','pushbutton','string','Subir Gain',...
    'position',[50 138 75 30],'callback',@subirgain,'fontsize',10);
bot(6)=uicontrol('parent',figura,'style','pushbutton','string','Bajar Gain',...
    'position',[50 98 75 30],'callback',@bajargain,'fontsize',10);
bot(9)=uicontrol('parent',figura,'style','slider','position',[50 10 200 30],'callback',@dist);
bot(9).Min=1800; bot(9).Max=50000; bot(9).Value=distance; bot(9).SliderStep=[1/241 0.1];

stop=false; play=false; restart=false; exit_program=false;

%% Funcion PARAR
function varargout=parar(hObject,evendata)
stop=true;
end

%% Funcion INICIAR
function varargout=iniciar(hObject,evendata)
play=true;
end

%% Funcion REINICIAR
function varargout=reiniciar(hObject,evendata)
restart=true;
end

%% Funcion SALIR
function varargout=salir(hObject,evendata)
exit_program=true;
end

%% Funcion SUBIR GAIN
function varargout=subirgain(hObject,evendata)
if ganancia~=2
    ganancia=ganancia+1;
    G.String=num2str(ganancia,'%u');
    cambiaGain=1;
end
end

%% Funcion BAJAR GAIN
function varargout=bajargain(hObject,evendata)
if ganancia~=0
    ganancia=ganancia-1;
    G.String=num2str(ganancia,'%u');
    cambiaGain=1;
end
end

%% Funcion DISTANCIA
function varargout=dist(hObject,evendata)
    distance=round(bot(9).Value);
    D.String=num2str(distance,'%u');
    cambiaDist=1;
end
end
