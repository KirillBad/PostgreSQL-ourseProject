PGDMP     ;                    {            hotel    15.1    15.1 =    =           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            >           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            ?           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            @           1262    17359    hotel    DATABASE     y   CREATE DATABASE hotel WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';
    DROP DATABASE hotel;
                postgres    false            �            1255    17453    booking_check()    FUNCTION     �  CREATE FUNCTION public.booking_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$	DECLARE 
		check_in_closest_room INT := (SELECT check_in_code FROM check_in WHERE room_code = NEW.room_code AND checkoutdate = (SELECT MAX(checkoutdate) FROM check_in WHERE room_code = NEW.room_code));
	BEGIN
		IF (SELECT (NEW.checkindate, NEW.checkoutdate) OVERLAPS (checkindate, checkoutdate) FROM check_in WHERE check_in_code = check_in_closest_room) = true THEN
			RAISE NOTICE 'Данный номер уже занят в эти даты';
			RETURN NULL;
		ELSE
			IF (SELECT (NEW.checkindate, NEW.checkoutdate) OVERLAPS (checkindate, checkoutdate) FROM booking WHERE room_code = NEW.room_code) = true THEN
				RAISE NOTICE 'Данный номер уже забронирован в эти даты';
				RETURN NULL;
			ELSE 
				RAISE NOTICE 'Вы успешно забронировали номер';
				RETURN NEW;
			END IF;
		END IF;			
	END;
$$;
 &   DROP FUNCTION public.booking_check();
       public          postgres    false            �            1255    17470    categories_counter()    FUNCTION     -  CREATE FUNCTION public.categories_counter() RETURNS TABLE(category_name character varying, category_counts integer)
    LANGUAGE sql
    AS $$
	SELECT categoryname, count(*) FROM categories JOIN clients_category ON categories.category_code = clients_category.category_code
	GROUP BY categoryname;
$$;
 +   DROP FUNCTION public.categories_counter();
       public          postgres    false            �            1255    17449    checking_in()    FUNCTION     �  CREATE FUNCTION public.checking_in() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		booking_checkindate date := (SELECT checkindate FROM booking WHERE client_code = NEW.client_code AND room_code = NEW.room_code);
		booking_checkoutdate date := (SELECT checkoutdate FROM booking WHERE client_code = NEW.client_code AND room_code = NEW.room_code);
		booking_current_code int := (SELECT booking_code FROM booking WHERE client_code = NEW.client_code AND room_code = NEW.room_code);
	BEGIN
		IF (SELECT busy FROM rooms WHERE room_code = NEW.room_code) = true THEN
			RAISE NOTICE 'Данный номер уже занят';
			RETURN NULL;
		ELSE 
			IF (SELECT (NEW.checkindate, NEW.checkoutdate) OVERLAPS (checkindate, checkoutdate) FROM booking WHERE room_code = NEW.room_code AND client_code != NEW.client_code) = true THEN
				RAISE NOTICE 'Данный номер забронирован в эти даты';
				RETURN NULL;
			ELSEIF (NEW.checkindate = booking_checkindate AND NEW.checkoutdate = booking_checkoutdate) THEN
				DELETE FROM booking WHERE booking_code = booking_current_code;
				RAISE NOTICE 'Вы успешно заселились, данные о вашем бронировании удалены';
				RETURN NEW;
			ELSE 
				RAISE NOTICE 'Вы успешно заселились';
				UPDATE rooms SET busy = true WHERE room_code = NEW.room_code ;
				RETURN NEW;
			END IF;
		END IF;
	END;
$$;
 $   DROP FUNCTION public.checking_in();
       public          postgres    false            �            1255    17460    passport_data_check()    FUNCTION     2  CREATE FUNCTION public.passport_data_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ 
	BEGIN
		IF (SUBSTRING(NEW.passport, 5, 1) = ' ') THEN 
			RETURN NEW; 
		ELSE 
			RAISE NOTICE 'Введены некорректные паспортные данные!'; 
			RETURN NULL; 
		END IF; 
	END;
$$;
 ,   DROP FUNCTION public.passport_data_check();
       public          postgres    false            �            1255    17456    price_calculate()    FUNCTION       CREATE FUNCTION public.price_calculate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE
		room_price INT := (SELECT price FROM rooms WHERE room_code = NEW.room_code);
		total_discount double precision;
	BEGIN
		IF (SELECT SUM(sale_percent)*0.01 FROM categories JOIN clients_category ON categories.category_code = clients_category.category_code WHERE client_code = NEW.client_code) > 0 THEN
			total_discount := (SELECT SUM(sale_percent)*0.01 FROM categories JOIN clients_category ON categories.category_code = clients_category.category_code WHERE client_code = NEW.client_code);
		ELSE
			total_discount := 0;
		END IF;
		UPDATE check_in SET pricewithdiscount = (room_price - (room_price * total_discount)) WHERE check_in_code = NEW.check_in_code;
		RETURN NEW;
	END;
$$;
 (   DROP FUNCTION public.price_calculate();
       public          postgres    false            �            1255    17466    room_busy_changer(date) 	   PROCEDURE     U  CREATE PROCEDURE public.room_busy_changer(IN curr_date date)
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		current_room record;
	BEGIN
		FOR current_room IN SELECT rooms.room_code, busy, checkoutdate, note FROM rooms JOIN check_in ON rooms.room_code = check_in.room_code
		LOOP
			IF (current_room.note = 'Выселен') THEN CONTINUE;
			END IF;
			IF (curr_date = current_room.checkoutdate) THEN 
				UPDATE rooms SET busy = false WHERE room_code = current_room.room_code;
				UPDATE check_in SET note = 'Выселен' WHERE room_code = current_room.room_code;
			END IF;
		END LOOP;
	END;
$$;
 <   DROP PROCEDURE public.room_busy_changer(IN curr_date date);
       public          postgres    false            �            1255    17463    rooms_comfortlevel()    FUNCTION       CREATE FUNCTION public.rooms_comfortlevel() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		CASE
			WHEN NEW.price >= 0 AND NEW.price <= 3000 THEN
				UPDATE rooms SET comfortlevel = 'Обычный' WHERE room_code = NEW.room_code;
			WHEN NEW.price > 3000 AND NEW.price <= 7000 THEN
				UPDATE rooms SET comfortlevel = 'Полулюкс' WHERE room_code = NEW.room_code;
			WHEN NEW.price > 7000 THEN
				UPDATE rooms SET comfortlevel = 'Люкс' WHERE room_code = NEW.room_code;
		END CASE;
		RETURN NEW;
	END;
$$;
 +   DROP FUNCTION public.rooms_comfortlevel();
       public          postgres    false            �            1255    17469 &   total_earnings_in_interval(date, date)    FUNCTION     �  CREATE FUNCTION public.total_earnings_in_interval(start_date date, end_date date) RETURNS TABLE(date_interval character varying, total_earnings character varying)
    LANGUAGE sql
    AS $$
    SELECT CONCAT('С ', TO_CHAR(start_date, 'YYYY-MM-DD'), ' по ', TO_CHAR(end_date, 'YYYY-MM-DD')) AS date_interval,
           CONCAT(CAST(SUM(pricewithdiscount) AS varchar), ' руб.') AS total_earnings
    FROM check_in
    WHERE checkindate >= start_date AND checkindate < end_date;
$$;
 Q   DROP FUNCTION public.total_earnings_in_interval(start_date date, end_date date);
       public          postgres    false            �            1259    17411    booking    TABLE     �   CREATE TABLE public.booking (
    booking_code integer NOT NULL,
    client_code integer,
    room_code integer,
    checkindate date NOT NULL,
    checkoutdate date NOT NULL,
    note character varying(200)
);
    DROP TABLE public.booking;
       public         heap    postgres    false            �            1259    17410    booking_booking_code_seq    SEQUENCE     �   CREATE SEQUENCE public.booking_booking_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.booking_booking_code_seq;
       public          postgres    false    223            A           0    0    booking_booking_code_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.booking_booking_code_seq OWNED BY public.booking.booking_code;
          public          postgres    false    222            �            1259    17368 
   categories    TABLE     �   CREATE TABLE public.categories (
    category_code integer NOT NULL,
    categoryname character varying(30) NOT NULL,
    sale_percent integer NOT NULL,
    description character varying(300) NOT NULL
);
    DROP TABLE public.categories;
       public         heap    postgres    false            �            1259    17367    categories_category_code_seq    SEQUENCE     �   CREATE SEQUENCE public.categories_category_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.categories_category_code_seq;
       public          postgres    false    217            B           0    0    categories_category_code_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.categories_category_code_seq OWNED BY public.categories.category_code;
          public          postgres    false    216            �            1259    17394    check_in    TABLE     �   CREATE TABLE public.check_in (
    check_in_code integer NOT NULL,
    client_code integer,
    room_code integer,
    checkindate date NOT NULL,
    checkoutdate date NOT NULL,
    note character varying(200),
    pricewithdiscount double precision
);
    DROP TABLE public.check_in;
       public         heap    postgres    false            �            1259    17393    check_in_check_in_code_seq    SEQUENCE     �   CREATE SEQUENCE public.check_in_check_in_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.check_in_check_in_code_seq;
       public          postgres    false    221            C           0    0    check_in_check_in_code_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.check_in_check_in_code_seq OWNED BY public.check_in.check_in_code;
          public          postgres    false    220            �            1259    17361    clients    TABLE       CREATE TABLE public.clients (
    client_code integer NOT NULL,
    lastname character varying(30) NOT NULL,
    firstname character varying(30) NOT NULL,
    middlename character varying(30),
    passport character varying(11) NOT NULL,
    comment character varying(255)
);
    DROP TABLE public.clients;
       public         heap    postgres    false            �            1259    17427    clients_category    TABLE     o   CREATE TABLE public.clients_category (
    client_code integer NOT NULL,
    category_code integer NOT NULL
);
 $   DROP TABLE public.clients_category;
       public         heap    postgres    false            �            1259    17360    clients_client_code_seq    SEQUENCE     �   CREATE SEQUENCE public.clients_client_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.clients_client_code_seq;
       public          postgres    false    215            D           0    0    clients_client_code_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.clients_client_code_seq OWNED BY public.clients.client_code;
          public          postgres    false    214            �            1259    17387    rooms    TABLE     �   CREATE TABLE public.rooms (
    room_code integer NOT NULL,
    roomnumber integer NOT NULL,
    capacity smallint NOT NULL,
    comfortlevel character varying(8),
    price integer NOT NULL,
    busy boolean DEFAULT false NOT NULL
);
    DROP TABLE public.rooms;
       public         heap    postgres    false            �            1259    17386    rooms_room_code_seq    SEQUENCE     �   CREATE SEQUENCE public.rooms_room_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.rooms_room_code_seq;
       public          postgres    false    219            E           0    0    rooms_room_code_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.rooms_room_code_seq OWNED BY public.rooms.room_code;
          public          postgres    false    218            �           2604    17414    booking booking_code    DEFAULT     |   ALTER TABLE ONLY public.booking ALTER COLUMN booking_code SET DEFAULT nextval('public.booking_booking_code_seq'::regclass);
 C   ALTER TABLE public.booking ALTER COLUMN booking_code DROP DEFAULT;
       public          postgres    false    223    222    223            �           2604    17371    categories category_code    DEFAULT     �   ALTER TABLE ONLY public.categories ALTER COLUMN category_code SET DEFAULT nextval('public.categories_category_code_seq'::regclass);
 G   ALTER TABLE public.categories ALTER COLUMN category_code DROP DEFAULT;
       public          postgres    false    216    217    217            �           2604    17397    check_in check_in_code    DEFAULT     �   ALTER TABLE ONLY public.check_in ALTER COLUMN check_in_code SET DEFAULT nextval('public.check_in_check_in_code_seq'::regclass);
 E   ALTER TABLE public.check_in ALTER COLUMN check_in_code DROP DEFAULT;
       public          postgres    false    220    221    221            �           2604    17364    clients client_code    DEFAULT     z   ALTER TABLE ONLY public.clients ALTER COLUMN client_code SET DEFAULT nextval('public.clients_client_code_seq'::regclass);
 B   ALTER TABLE public.clients ALTER COLUMN client_code DROP DEFAULT;
       public          postgres    false    214    215    215            �           2604    17390    rooms room_code    DEFAULT     r   ALTER TABLE ONLY public.rooms ALTER COLUMN room_code SET DEFAULT nextval('public.rooms_room_code_seq'::regclass);
 >   ALTER TABLE public.rooms ALTER COLUMN room_code DROP DEFAULT;
       public          postgres    false    219    218    219            9          0    17411    booking 
   TABLE DATA           h   COPY public.booking (booking_code, client_code, room_code, checkindate, checkoutdate, note) FROM stdin;
    public          postgres    false    223   �[       3          0    17368 
   categories 
   TABLE DATA           \   COPY public.categories (category_code, categoryname, sale_percent, description) FROM stdin;
    public          postgres    false    217   ?\       7          0    17394    check_in 
   TABLE DATA           }   COPY public.check_in (check_in_code, client_code, room_code, checkindate, checkoutdate, note, pricewithdiscount) FROM stdin;
    public          postgres    false    221   �]       1          0    17361    clients 
   TABLE DATA           b   COPY public.clients (client_code, lastname, firstname, middlename, passport, comment) FROM stdin;
    public          postgres    false    215   �^       :          0    17427    clients_category 
   TABLE DATA           F   COPY public.clients_category (client_code, category_code) FROM stdin;
    public          postgres    false    224   �a       5          0    17387    rooms 
   TABLE DATA           [   COPY public.rooms (room_code, roomnumber, capacity, comfortlevel, price, busy) FROM stdin;
    public          postgres    false    219   b       F           0    0    booking_booking_code_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.booking_booking_code_seq', 11, true);
          public          postgres    false    222            G           0    0    categories_category_code_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.categories_category_code_seq', 5, true);
          public          postgres    false    216            H           0    0    check_in_check_in_code_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.check_in_check_in_code_seq', 36, true);
          public          postgres    false    220            I           0    0    clients_client_code_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.clients_client_code_seq', 22, true);
          public          postgres    false    214            J           0    0    rooms_room_code_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.rooms_room_code_seq', 1, true);
          public          postgres    false    218            �           2606    17416    booking booking_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_pkey PRIMARY KEY (booking_code);
 >   ALTER TABLE ONLY public.booking DROP CONSTRAINT booking_pkey;
       public            postgres    false    223            �           2606    17373    categories categories_pkey 
   CONSTRAINT     c   ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (category_code);
 D   ALTER TABLE ONLY public.categories DROP CONSTRAINT categories_pkey;
       public            postgres    false    217            �           2606    17399    check_in check_in_pkey 
   CONSTRAINT     _   ALTER TABLE ONLY public.check_in
    ADD CONSTRAINT check_in_pkey PRIMARY KEY (check_in_code);
 @   ALTER TABLE ONLY public.check_in DROP CONSTRAINT check_in_pkey;
       public            postgres    false    221            �           2606    17431 &   clients_category clients_category_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.clients_category
    ADD CONSTRAINT clients_category_pkey PRIMARY KEY (client_code, category_code);
 P   ALTER TABLE ONLY public.clients_category DROP CONSTRAINT clients_category_pkey;
       public            postgres    false    224    224            �           2606    17366    clients clients_pkey 
   CONSTRAINT     [   ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_code);
 >   ALTER TABLE ONLY public.clients DROP CONSTRAINT clients_pkey;
       public            postgres    false    215            �           2606    17392    rooms rooms_pkey 
   CONSTRAINT     U   ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (room_code);
 :   ALTER TABLE ONLY public.rooms DROP CONSTRAINT rooms_pkey;
       public            postgres    false    219            �           2620    17454    booking tr_booking_check    TRIGGER     v   CREATE TRIGGER tr_booking_check BEFORE INSERT ON public.booking FOR EACH ROW EXECUTE FUNCTION public.booking_check();
 1   DROP TRIGGER tr_booking_check ON public.booking;
       public          postgres    false    237    223            �           2620    17450    check_in tr_checking_in    TRIGGER     s   CREATE TRIGGER tr_checking_in BEFORE INSERT ON public.check_in FOR EACH ROW EXECUTE FUNCTION public.checking_in();
 0   DROP TRIGGER tr_checking_in ON public.check_in;
       public          postgres    false    221    238            �           2620    17461    clients tr_passport_data_check    TRIGGER     �   CREATE TRIGGER tr_passport_data_check BEFORE INSERT ON public.clients FOR EACH ROW EXECUTE FUNCTION public.passport_data_check();
 7   DROP TRIGGER tr_passport_data_check ON public.clients;
       public          postgres    false    215    239            �           2620    17457    check_in tr_price_calculator    TRIGGER     {   CREATE TRIGGER tr_price_calculator AFTER INSERT ON public.check_in FOR EACH ROW EXECUTE FUNCTION public.price_calculate();
 5   DROP TRIGGER tr_price_calculator ON public.check_in;
       public          postgres    false    221    236            �           2620    17464    rooms tr_rooms_comfortlevel    TRIGGER     }   CREATE TRIGGER tr_rooms_comfortlevel AFTER INSERT ON public.rooms FOR EACH ROW EXECUTE FUNCTION public.rooms_comfortlevel();
 4   DROP TRIGGER tr_rooms_comfortlevel ON public.rooms;
       public          postgres    false    219    240            �           2606    17417     booking booking_client_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_client_code_fkey FOREIGN KEY (client_code) REFERENCES public.clients(client_code);
 J   ALTER TABLE ONLY public.booking DROP CONSTRAINT booking_client_code_fkey;
       public          postgres    false    223    215    3212            �           2606    17422    booking booking_room_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.booking
    ADD CONSTRAINT booking_room_code_fkey FOREIGN KEY (room_code) REFERENCES public.rooms(room_code);
 H   ALTER TABLE ONLY public.booking DROP CONSTRAINT booking_room_code_fkey;
       public          postgres    false    219    223    3216            �           2606    17400 "   check_in check_in_client_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.check_in
    ADD CONSTRAINT check_in_client_code_fkey FOREIGN KEY (client_code) REFERENCES public.clients(client_code);
 L   ALTER TABLE ONLY public.check_in DROP CONSTRAINT check_in_client_code_fkey;
       public          postgres    false    221    3212    215            �           2606    17405     check_in check_in_room_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.check_in
    ADD CONSTRAINT check_in_room_code_fkey FOREIGN KEY (room_code) REFERENCES public.rooms(room_code);
 J   ALTER TABLE ONLY public.check_in DROP CONSTRAINT check_in_room_code_fkey;
       public          postgres    false    3216    219    221            �           2606    17437 4   clients_category clients_category_category_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.clients_category
    ADD CONSTRAINT clients_category_category_code_fkey FOREIGN KEY (category_code) REFERENCES public.categories(category_code);
 ^   ALTER TABLE ONLY public.clients_category DROP CONSTRAINT clients_category_category_code_fkey;
       public          postgres    false    3214    224    217            �           2606    17432 2   clients_category clients_category_client_code_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.clients_category
    ADD CONSTRAINT clients_category_client_code_fkey FOREIGN KEY (client_code) REFERENCES public.clients(client_code);
 \   ALTER TABLE ONLY public.clients_category DROP CONSTRAINT clients_category_client_code_fkey;
       public          postgres    false    3212    224    215            9   e   x�]���0��^�|$&4A��ň�xy���Za/qml7.��U�]!I�%��7Dŷh��Yx�E������
�o�7�+Qc�rnL5� �K�(      3   [  x�UR[N�0��O� j����/�PP�����NJhh��
�7bv�VEJ#gwvfg��]]\����,��b���e��+Th�H�*�5?Z�����>�Vs�j�#�6��D��5�%*�$Z�(q���0X��Cy�أ�sAP3�M���,��2��;|�0����N���AqT���4~���ZrVQȘ��`ƕ�/dJ����r�e
K?ʀ��PUnh�2EH�5l-Py���ne������	�N-5�h�i�}Ojd�R˝V����~Ѐ�𧪤�C[u�Q���@�9~��{�OO������Y���+y�.>����������� ������R�p      7   �   x�}��i1��O��˖�H�Lι���Bz��(�{B���}�����ڍ�eJ���x{���g�/Hi�9� ����ru�_���VI�rl����jLb��8O)< qo$%!�(�A�M�����"�=c-է��$�T ���
e�1�4b.�H�=���e���M)KlB��Z��#��J�#�t�Ҏ~���Ǿ/�
�~�rj�2�ɵ��+f��7"�ߔeM      1     x�}U[n�0�&O�� ���S��_9��hS Ҥy�E��Vc[�s��2���*v�aC����ٙ�StEc��V4^/�4�ʧ�0���yE����NhnhA-ͨ��@��=5� ��pq1ؕp.��)lUe�҉��1�U�+2O�hh΋����&޷��&M�++E�&������R��{�XP��j,g�L��/p8fǙZ9oK��,-J�3N��G���6������fk|���)+[d����Ð�\�-�D�$7�B���܀� �#zg����U�
XV��������ZQ����M��[M��S�ds� ���I���l��e��J���F��ᴃ�w�Vձ�}�me3�i嬢84�6�qO�uT1�Ud(¼������o��:Sd,�9�r~¡y߲Mi�mm[�Te� j��s8�0���}<��7O;�y:�<Fa����Kx�~�E_��$YY�u��Th��N�	����Ȱێ�(�p*M�]^l��7J�	I����;i�o����u>u��`���T�|*�r�Cw���p��w�����À!�
���˰�ab(�@���,~��3�K�֞04�{�p�����#�}M���/z�]���QCeQ�v%�6��"!1Wq'�L6"�X��5� 0ۯN<�g�''�N��	a+�<O!�b�����A�	��|4�����LZj'��E�k�_��ǄdN lW<Ƅ����.����*&~=6e��,�`"�;������k�?�>��?Xy��{��~P W      :   9   x���  ��0�'�U�q�9��� ,
��bLC!�=��v<�%kE��ʷ7H~Ue	P      5   �  x����m1���b�WR/>�7`䐃�4 �!G;�k�v�ޘF����#�CJR�J�2�_���u�9�S�&��d�+�2Η������|>�;���V�U�V��ka���̡�7���C����	X��	����k��uV`-R����&�����n�-��[t�����)�c$LEvKo�>B��iN��,�z��+������L6���m�3h�܀s3t�a�Ռ��2���a~$�DKB�=�[�_�gڢd���iX��3�k�<=ީ�X�����/��f��GmQM)�๫k��G���K�Kh��<�[if��o[˔�"���3��85\G�t\ko{@ڴY(Q����/����(�K��_�]�
���X��O�o` �W�«# �J�Jm��r�]yǿ�W�J@�S����z�oo��xaX��     