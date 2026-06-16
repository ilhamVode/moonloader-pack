script_name('News Helper')
script_version('4.3')
script_author('fa1ser')

local imgui         = require 'mimgui'
local ffi           = require 'ffi'
local encoding      = require 'encoding'
encoding.default    = 'CP1251'
local u8            = encoding.UTF8
local ev            = require 'samp.events'
local fa            = require 'fAwesome6'
local dlstatus 		= require('moonloader').download_status
local memory        = require('memory')

local chotkey, hotkey = pcall(require, 'mimgui_hotkeys')
if not chotkey then
    sampAddChatMessage("{FFFFFF}У вас отсутствует библиотека {FF0000}mimgui_hotkeys{FFFFFF}! Установите ее по ссылке -> https://www.blast.hk/threads/178867/", -1)
    return
end

local sizeX, sizeY = getScreenResolution()
local config_path = getWorkingDirectory() .. "\\config\\NH\\"
local cfg_default = {
    settings = {
        auto_send = false,
        delay = 10,
        auto_open_helper = false,
        suggestions_enabled = true
    },
    binds = {
        menu = '',
        catchAd = '',
        copyAd = '',
        fastMenu = '',
        helper = ''
    },
    ethers = {
        name = '', 
        duty = '', 
        tagCNN = '', 
        city = '', 
        server = 'Скоттдейл', 
        delay = 4,
        music = '•°•°•°•°Музыкальная заставка радиостанции г.•°•°•°•°'
    },
    theme = {
        WindowBg       = {0.07, 0.07, 0.09, 0.95},
        ChildBg        = {0.10, 0.10, 0.12, 0.50},
        PopupBg        = {0.08, 0.08, 0.10, 0.98},
        Border         = {0.15, 0.15, 0.18, 0.50},
        FrameBg        = {0.14, 0.14, 0.16, 1.00},
        FrameBgHovered = {0.18, 0.18, 0.20, 1.00},
        FrameBgActive  = {0.22, 0.22, 0.25, 1.00},
        TitleBg        = {0.07, 0.07, 0.09, 1.00},
        Button         = {0.35, 0.40, 0.95, 0.80},
        ButtonHovered  = {0.40, 0.45, 1.00, 0.90},
        ButtonActive   = {0.30, 0.35, 0.90, 1.00},
        Text           = {0.95, 0.95, 0.95, 1.00},
        Header         = {0.35, 0.40, 0.95, 0.80},
        Accent         = {0.35, 0.40, 0.95, 1.00}
    }
}

local pending_cef = {}
local cef_seq = 0

function load_json(path)
    if doesFileExist(path) then
        local file = io.open(path, 'r')
        if file then
            local contents = file:read('*a')
            file:close()
            if contents and #contents > 0 then
                local result, loaded = pcall(decodeJson, contents)
                if result then return loaded end
            end
        end
    end
    return nil
end

function save_json(path, data)
    local file, err = io.open(path, 'w')
    if file then
        local result, encoded = pcall(encodeJson, data)
        if result then
            file:write(encoded)
            file:close()
            return true
        end
        file:close()
    end
    return false
end

function cLog(text)
	print(u8:decode('{008080}[News Helper] {FFFFFF}' .. text))
end

function lower_cp1251(s)
    local res = {}
    for i = 1, #s do
        local b = s:byte(i)
        if b >= 192 and b <= 223 then b = b + 32
        elseif b == 168 then b = 184 end
        table.insert(res, string.char(b))
    end
    return table.concat(res):lower()
end

function notif(type, title, text, time)
    type = type or 'info'
    title = title or 'Заголовок'
    text = text or 'Текст'
    time = time or 2000
    local json = string.format('[%q,%q,%q,%d]', type, title, text, time)
    local code = "window.executeEvent('event.notify.initialize', `" .. json .. "`);"
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

local cfg = load_json(config_path .. 'settings.json')
if not cfg then cfg = cfg_default end

local tabs_names = {
    {fa('HOUSE'), 'Главная'}, 
    {fa('PEN_TO_SQUARE'), 'Редакция'}, 
    {fa('CHART_BAR'), 'Статистика'},
    {fa('HEADSET'), 'Эфиры'},
    {fa('USER'), 'Собеседование'},
    {fa('GRADUATION_CAP'), 'Экзамены'},
    {fa('GEAR'), 'Настройки'}
}
local anims = {
    menu_btns = {},
    content_alpha = 0,
    main_alpha = 0,
    helper_alpha = 0,
    main_target = false,
    helper_target = false,
    sugg_alpha = 0,
    sugg_target = false
}
local edit_modal = {
    state = imgui.new.bool(false),
    index = 0,
    original = imgui.new.char[256](),
    edited = imgui.new.char[256]() 
}
local win = {
    main = imgui.new.bool(false),
    helper = imgui.new.bool(false)
}
local autobind_buffers = {
    replace_char_buffer = imgui.new.char[256](),
    new_bind_key = imgui.new.char[256](),
    new_bind_value = imgui.new.char[256](),
    new_hotkey_bind_value = imgui.new.char[256](),
    edit_bind_key = imgui.new.char[256](),
    edit_bind_value = imgui.new.char[256](),
    edit_hotkey_bind_value = imgui.new.char[256]()
}
local help_tabs_info = {
    first = {
        {'Покупка/продажа вещей/транспорта',
            {'Продам машину','Продам а/м "*". Цена: '},
            {'Куплю машину','Куплю а/м "*". Бюджет: '},
            {'Куплю машину любой модели','Куплю а/м любой марки. Бюджет: '},
            {'Продам мотоцикл','Продам м/ц "*". Цена: '},
            {'Куплю мотоцикл','Куплю м/ц "*". Бюджет: '},
            {'Продам лодку', 'Продам л/д "*". Цена: '},
            {'Продам вертолет', 'Продам в/т "*". Цена: '},
            {'Продам фуру', 'Продам г/м  "*". Цена: '},
            {'Куплю аксессуар','Куплю а/с "*". Бюджет: '},
            {'Продам аксессуар','Продам а/с "*". Цена: '},
            {'Куплю аксессуар с заточкой','Куплю а/с "*" с гравировкой "+*". Бюджет: '},
            {'Продам аксессуар с заточкой','Продам а/с "*" с гравировкой "+*". Цена: '},
            {'Куплю скин','Куплю о/п с любого типа. Бюджет: '},
        },{'Продажа/покупка домов/бизнесов',
            {'Продам бизнес в ЛС','Продам б/з "*" в г. Лос-Сантос. Цена: '},
            {'Куплю бизнес в ЛС','Куплю б/з "*" в г. Лос-Сантос. Бюджет: '},
            {'Куплю бизнесов','Куплю б/з "*" в любой точке штата. Бюджет: '},
            {'Продам бизнесов','Продам б/з "*" #* . Цена:'},
            {'Продам дом', 'Продам дом *. Цена: '},
            {'Куплю дом', 'Куплю дом *. Бюджет: '},
        },{'Собеседования',
            {'СМИ г. ЛС', 'Проходит собеседование в СМИ г. Лос-Сантос. Ждем в холле!'},
            {'СМИ г. СФ', 'Проходит собеседование в СМИ г. Сан-Фиерро. Ждем в холле!'},
            {'СМИ г. ЛВ', 'Проходит собеседование в СМИ г. Лас-Вентурас. Ждем в холле!'},
            {'Полиция', 'Проходит собеседование в полицию г. *. Ждем в холле!'},
            {'Больница', 'Проходит собеседование в больницу г. *. Ждем в холле!'},
        },{'Семьи',
            {'Ищу семью', 'Ищу семью. О себе при встрече. Просьба связаться'},
            {'Ищу семью (все улучшения)', 'Ищу семью со всеми нашивками. Жду звоночка!'},
            {'Продам семью', 'Продам права на владение семьей. Цена: *'},
            {'Продам семью (все улучшения)', 'Продам права на владение семьей со всеми нашивками. Цена: *'},
            {'Набор в семью', 'Семья * ищет дальних родственников. Жду звонка!'},
            {'Набор в семью (все улучшения)', 'Семья * со всеми нашивками ищет дальних родственников. Жду звонка!'},
        },{'Реклама бизнесов',
            {'Работает бар','Работает бар #*, у нас самая вкусная еда и напитки! Приезжайте'},
            {'Работает закусочная','Работает закусочная #*, у нас самые дешевые цены во всем штате'},
            {'Работает отель','Работает отель #*, у нас самое дешевое заселение! Приезжайте'},
            {'Работает 24/7','Работает магазин 24/7 #*, у нас самые дешевые цены! Успей закупиться'},
            {'Работает АЗС','Работает АЗС #*, у нас самое качественное топливо. Ждем вас'},
            {'Работает аммунация','Работает аммунация #*, у нас самые качественные боеприпасы. '},
            {'Работает СТО по ремонту','Работает СТО по ремонту двигателей в д. *. У нас все дешево'},
            {'Работает СТО по тюнингу','Работает СТО в г. *, быстрый и качественный тюнинг вашего автомобиля'},
            {'Работает ремонт одежды','Порвалась одежды? Тогда тебе в Ремонт Одежды #* в д.'},
            {'Работает школа танцев','Хочешь чтобы все девочки были твои? Тебе в школу танцев г. *'},
            {'Работает магазин одежды','Не хочешь выглядеть как бомж? Тогда тебе в магазин одежды #*'},
            {'Работает нефтевышка', 'Самая лучшая нефть только у нас! Приезжай на нефтевышку #*'},
        },{'Реклама организаций/Собеседования',
            {'Реклама СМИ LS', 'Работает СМИ г.Лос-Сантос! Ждем ваших объявлений'},
            {'Реклама СМИ LV', 'Работает СМИ г.Лас-Вентурас! Ждем ваших объявлений'},
            {'Реклама СМИ SF', 'Работает СМИ г.Сан-Фиерро! Ждем ваших объявлений'},
            {'Собеседование в СМИ','Проходит собеседование в СМИ г. *. Ждем Вас!'},
            {'Собеседование в полицию','Проходит собеседование в полицию г. *. Ждем в холле!'},
            {'Собеседование в больницу','Проходит собеседование в больницу г. *. Ждем Вас! '},
            {'Собеседование в ДТЛ','Проходит собеседование в ДТЛ! Ждем именно тебя!'},
            {'Собеседование в ТСР','Проходит собеседование в Тюрьму Строгого Режима! Ждем Вас!'},
            {'Собеседование в армию','Проходит собеседование в армию г. *! Ждем вас в военкомате! '},
            {'Собеседование в СТК', 'Проходит собеседование в Страховую Компанию! Ждем именно тебя!'},
            {'Собеседование в Правительство','Проходит собеседование в Правительство! Ждем Вас в холле!'},
            {'Собеседование в Warlock MC','Проходит собеседование в бар "Бородатая фея". Ждем в баре'},
            {'Собеседование в Russian Mafia','Проходит собеседование в ЦВСП "Русская Мафия". Встреча у особняка'},
            {'Собеседование в LCN','Проходит набор в СК "Чарлиз". Встреча у особняка'},
            {'Собеседование в Yakuza','Проходит собеседование в японский ресторан "Yakuza". Встреча в ресторане'},
            {'Собеседование в Tierra Robada Bikers', 'Проходит собеседование в бар "Tierra Robada Bikers". Ждем в баре'},
            {'Собеседование в Night Wolfs','Проходит собеседование в БК "Night Wolfs". Желающих ждём на районе'},
            {'Собеседование в Groove','Проходит набор в БК "Groove".  Желающих ждём на районе'},
            {'Собеседование в Ballas','Проходит набор в БК "Ballas". Желающих ждём на районе'},
            {'Собеседование в Vagos','Проходит набор в БК "Vagos". Желающих ждём на районе'},
            {'Собеседование в Aztecas','Проходит набор в БК "Aztec". Желающих ждём на районе'},
            {'Собеседование в Rifa','Проходит набор в БК "Rifa". Желающих ждём на районе'},
        }
    },
    second = {
        {'авто', 'а/м'},
        {'мотоцикл', 'м/ц'},
        {'самолет', 'с/т'},
        {'тюнинг', 'д/т'},
        {'бизнес', 'б/з'},
        {'фура', 'г/м'},
        {'охра', 'в/о'},
        {'Цена: договорная', 'Цена: договорная'},
        {'Бюджет: свободный', 'Бюджет: свободный'}
    }
}
local ethers = {
    data = {
        settings = cfg.ethers,
        events = {
            mathem = {
                title = 'Математика',
                tag = '[Математика]: ',
                lines = {
                    {fa('PLAY'), 'Начать эфир', {
                        '/d [{tagCNN}] to [СМИ] Занял эфирную волну, не перебивайте.',
                        '/news {music}',
                        '/news {tag}Всем доброго времени суток, уважаемые жители штата {server}!',
                        '/news {tag}Для вас вещает {duty} радиоцентра г. {city} — {name}.',
                        '/news {tag}Прямо сейчас мы проведем увлекательную игру на тему "Математика"!',
                        '/news {tag}Отвлекитесь от забот и проверьте свои знания.',
                        '/news {tag}Суть игры предельно проста:',
                        '/news {tag}Я буду называть математические примеры, а ваша задача — прислать правильный ответ.',
                        '/news {tag}Тот, чей ответ придет первым, зарабатывает один балл. Игра идет до {scores} очков.',
                        '/news {tag}Победитель заберет домой денежный приз в размере {prize}!',
                        '/news {tag}Отличное пополнение вашего бюджета!',
                        '/news {tag}Берем в руки телефоны, заходим в контакты и ищем «Написать в СМИ {city}».',
                        '/news {tag}Приготовьтесь, мы начинаем игру!'
                    }},
                    {fa('PAPER_PLANE'), 'Следующий пример', {'/news {tag}Слушаем следующий пример...'}},
                    {fa('CIRCLE_STOP'), 'Стоп!', {'/news {tag}Внимание, стоп-игра!'}},
                    {fa('TRIANGLE_EXCLAMATION'), 'Тех. неполадки!', {'/news {tag}Возникли небольшие тех. проблемы, оставайтесь с нами!'}},
                    {fa('CHEVRON_RIGHT'), 'Первым был', {'/news {tag}Самым быстрым оказался {ID}! На его счету уже {scoreID} баллов!'}},
                    {fa('TROPHY'), 'Назвать победителя', {
                        '/news {tag}У нас определился чемпион сегодняшней игры!',
                        '/news {tag}Барабанная дробь...',
                        '/news {tag}Это неподражаемый {ID}! Вы первым набрали заветные {scores} победных очков.',
                        '/news {tag}{ID}, примите поздравления! Вы выиграли ровно {prize}!',
                        '/news {tag}Ждем вас в кратчайшие сроки...',
                        '/news {tag}...на ресепшене радиоцентра г. {city} за вашим призом!'
                    }},
                    {fa('STOP'), 'Закончить эфир', {
                        '/news {tag}На этом наша передача подходит к завершению.',
                        '/news {tag}Огромное спасибо всем, кто принимал участие и звонил нам.',
                        '/news {tag}Надеюсь, эта математическая разминка пришлась вам по душе!',
                        '/news {tag}Эфир провел {name}, {duty} радиостанции г. {city}.',
                        '/news {tag}Желаю всем отличного настроения и крепкого здоровья вам и вашим близким!',
                        '/news {tag}До новых встреч на наших волнах!',
                        '/news {music}',
                        '/d [{tagCNN}] to [СМИ] Освобождаю эфирную волну, благодарю за ожидание.'
                    }}
                }
            },
            capitals = {
                title = 'Столицы',
                tag = '[Столицы]: ',
                lines = {
                    {fa('PLAY'), 'Начать эфир', {
                        '/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну, прошу не занимать.',
                        '/news {music}',
                        '/news {tag}Приветствую всех радиослушателей прекрасного штата {server}!',
                        '/news {tag}У микрофона находится {duty} из студии г. {city} — {name}.',
                        '/news {tag}Оставляйте дела, сегодня у нас эфир под названием "Столицы"!',
                        '/news {tag}Готовы блеснуть знаниями географии?',
                        '/news {tag}Кратко о правилах:',
                        '/news {tag}Я буду в прямом эфире озвучивать название страны...',
                        '/news {tag}... а вы должны как можно быстрее прислать название её столицы.',
                        '/news {tag}Слушатель, который первым отправляет верный ответ, получает балл.',
                        '/news {tag}Как только кто-то наберет {scores} баллов — игра окончится.',
                        '/news {tag}Наш призовой фонд на сегодня составляет весьма приятные {prize}!',
                        '/news {tag}Такие деньги на дороге не валяются!',
                        '/news {tag}Для ответов используйте свои мобильные устройства: контакты -> «Написать в СМИ»...',
                        '/news {tag}... далее выбираете станцию г. {city} и отправляете сообщение.',
                        '/news {tag}Все готовы? Тогда вперед!'
                    }},
                    {fa('PAPER_PLANE'), 'Следующий вопрос', {'/news {tag}Внимание, следующий вопрос...'}},
                    {fa('CIRCLE_STOP'), 'Стоп!', {'/news {tag}Ответы больше не принимаются, стоп!'}},
                    {fa('TRIANGLE_EXCLAMATION'), 'Тех. неполадки!', {'/news {tag}В эфире небольшие помехи, скоро вернемся...'}},
                    {fa('CHEVRON_RIGHT'), 'Первым был', {'/news {tag}Первый правильный ответ дал {ID}! И у него уже {scoreID} очков!'}},
                    {fa('TROPHY'), 'Назвать победителя', {
                        '/news {tag}А вот и наш победитель!',
                        '/news {tag}Встречайте знатока географии...',
                        '/news {tag}Им становится {ID}! Вы достигли отметки в {scores} баллов быстрее всех!',
                        '/news {tag}{ID}, мы вас сердечно поздравляем! Ваш приз: {prize}!',
                        '/news {tag}Ожидаем вас в нашем здании...',
                        '/news {tag}... радиоцентра города {city}, чтобы выдать наличные.'
                    }},
                    {fa('STOP'), 'Закончить эфир', {
                        '/news {tag}Вот и подошел к концу наш географический эфир.',
                        '/news {tag}Пришло время прощаться.',
                        '/news {tag}Было очень здорово проверить ваши знания столиц мира.',
                        '/news {tag}В студии для вас работал {name}, {duty} радиостанции г. {city}.',
                        '/news {tag}Развивайтесь, читайте книги и берегите себя!',
                        '/news {tag}Скоро услышимся на этой же волне!',
                        '/news {music}',
                        '/d [{tagCNN}] to [СМИ] Развлекательную волну покинул. Конец связи.'
                    }}
                }
            },
            greet = {
                title = 'Приветы',
                tag = '[Приветы]: ',
                lines = {
                    {fa('PLAY'), 'Начать эфир', {
                        '/d [{tagCNN}] to [СМИ] Вещаю на развлекательной волне, прошу не мешать.',
                        '/news {music}',
                        '/news {tag}Всем доброго времени суток, дорогие жители штата {server}.',
                        '/news {tag}Для вас работает {name}, {duty} радиостанции г. {city}.',
                        '/news {tag}Начинаем самый добрый эфир — "Приветы и поздравления"!',
                        '/news {tag}Это отличная возможность порадовать своих близких...',
                        '/news {tag}Правила предельно понятны:',
                        '/news {tag}Вы отправляете в нашу студию сообщения с тёплыми словами, ...',
                        '/news {tag}... а я с удовольствием озвучиваю их на весь {server}.',
                        '/news {tag}Напомню, как с нами связаться:',
                        '/news {tag}Открываете телефонную книгу, ищете пункт «Написать в СМИ»...',
                        '/news {tag}... выбираете радиостанцию г. {city} и печатаете текст.',
                        '/news {tag}Мы будем в эфире примерно {time} минут, так что успеют многие!',
                        '/news {tag}С нетерпением жду ваши сообщения. Поехали!'
                    }},
                    {fa('PAPER_PLANE'), 'Передать привет', {'/news {tag}Житель {ID} передает огромный привет гражданину {toID}!'}},
                    {fa('TRIANGLE_EXCLAMATION'), 'Тех. неполадки!', {'/news {tag}Возникла небольшая заминка, оставайтесь на нашей частоте...'}},
                    {fa('STOP'), 'Закончить эфир', {
                        '/news {tag}Вот и подошел к концу наш эфир.',
                        '/news {tag}Было очень приятно зачитывать ваши светлые пожелания.',
                        '/news {tag}Надеюсь, каждый услышал свой долгожданный привет!',
                        '/news {tag}Для вас работал {name}, {duty} радиостанции г. {city}.',
                        '/news {tag}Любите друг друга и будьте счастливы!',
                        '/news {tag}Увидимся в следующих включениях!',
                        '/news {music}',
                        '/d [{tagCNN}] to [СМИ] Заканчиваю развлекательный эфир, волна свободна.'
                    }}
                }
            },
            chemic = {
                title = 'Хим. элементы',
                tag = '[Хим.Элементы]: ',
                lines = {
                    {fa('PLAY'), 'Начать эфир', {
                        '/d [{tagCNN}] to [СМИ] Беру микрофон для развлекательного эфира.',
                        '/news {music}',
                        '/news {tag}Рад приветствовать всех радиослушателей штата {server}!',
                        '/news {tag}В эфире {name}, занимающий должность {duty} в г. {city}.',
                        '/news {tag}Сегодня мы проверим ваши знания в области химии!',
                        '/news {tag}А именно – знание химических элементов.',
                        '/news {tag}Правила игры следующие:',
                        '/news {tag}Я называю символ химического элемента из таблицы Менделеева...',
                        '/news {tag}... а вы должны как можно скорее прислать его полное название.',
                        '/news {tag}Например: я говорю "О", а вы пишете мне "Кислород".',
                        '/news {tag}Тот, кто первым угадает {scores} элементов, станет абсолютным победителем.',
                        '/news {tag}Сегодняшний приз составляет {prize}!',
                        '/news {tag}Ждем ваши правильные ответы.',
                        '/news {tag}Смс отправляйте к нам в радиоцентр...',
                        '/news {tag}Возьмите телефон, выберите «Написать в СМИ»...',
                        '/news {tag}... далее г. {city} — и отправляйте.',
                        '/news {tag}Первый элемент уже на подходе!'
                    }},
                    {fa('PAPER_PLANE'), 'Следующий элемент', {'/news {tag}Внимание, следующий химический элемент...'}},
                    {fa('CIRCLE_STOP'), 'Стоп!', {'/news {tag}Хватит, правильный ответ уже получен!'}},
                    {fa('TRIANGLE_EXCLAMATION'), 'Тех. неполадки!', {'/news {tag}Технические проблемы с микрофоном, минутку тишины...'}},
                    {fa('CHEVRON_RIGHT'), 'Первым был', {'/news {tag}Отлично! Самым быстрым химиком оказался {ID}! Это его {scoreID}-й балл!'}},
                    {fa('TROPHY'), 'Назвать победителя', {
                        '/news {tag}Игра завершена, победитель установлен!',
                        '/news {tag}Аплодисменты...',
                        '/news {tag}Это наш гениальный слушатель {ID}! Вы смогли верно назвать {scores} элементов!',
                        '/news {tag}{ID}, поздравляем с победой! Ваша заслуженная награда: {prize}!',
                        '/news {tag}Просьба не задерживаться и приехать за деньгами...',
                        '/news {tag}... прямо в студию СМИ г. {city}. Ждем вас!'
                    }},
                    {fa('STOP'), 'Закончить эфир', {
                        '/news {tag}Уважаемые слушатели, пора закругляться!',
                        '/news {tag}Химия — наука сложная, но безумно интересная.',
                        '/news {tag}Спасибо всем, кто сегодня ломал голову вместе с нами.',
                        '/news {tag}У микрофона был {duty} радиоцентра г. {city} — {name}.',
                        '/news {tag}Стремитесь к знаниям и делайте новые открытия!',
                        '/news {tag}Услышимся совсем скоро!',
                        '/news {music}',
                        '/d [{tagCNN}] to [СМИ] Эфир окончен, микрофон выключен. Волна свободна.'
                    }}
                }
            },
            interpreter = {
                title = 'Переводчики',
                tag = '[Переводчики]: ',
                lines = {
                    {fa('PLAY'), 'Начать эфир', {
                        '/d [{tagCNN}] to [СМИ] Начинаю развлекательный эфир.',
                        '/news {music}',
                        '/news {tag}Приветствую всех жителей великолепного штата {server}!',
                        '/news {tag}Из студии г. {city} вещает {duty} —',
                        '/news {tag}Это я, ваш неизменный {name}!',
                        '/news {tag}Запускаем интеллектуальную игру "Переводчики".',
                        '/news {tag}Навострите уши и подготовьте ваши словари!',
                        '/news {tag}Я буду задавать слова на {language}ом языке, а от вас жду точный перевод.',
                        '/news {tag}Это испытание для самых настоящих полиглотов.',
                        '/news {tag}Для победы участнику требуется набрать ровно {scores} баллов.',
                        '/news {tag}Фонд нашей сегодняшней игры составляет {prize}!',
                        '/news {tag}Вполне щедрая сумма за ваши старания.',
                        '/news {tag}Отвечать на вопросы нужно через текстовые сообщения...',
                        '/news {tag}Открывем телефон, контакты, отправка сообщения в СМИ...',
                        '/news {tag}Обязательно выбираем радиостанцию г. {city} и шлём ответ.',
                        '/news {tag}Приготовьтесь, первое слово прозвучит прямо сейчас!'
                    }},
                    {fa('PAPER_PLANE'), 'Следующее слово', {'/news {tag}А вот и следующее слово на наш суд...'}},
                    {fa('CIRCLE_STOP'), 'Стоп!', {'/news {tag}Время вышло, верный вариант уже принят!'}},
                    {fa('TRIANGLE_EXCLAMATION'), 'Тех. неполадки!', {'/news {tag}Пропал звук... Ожидайте, скоро восстановим вещание.'}},
                    {fa('CHEVRON_RIGHT'), 'Первым был', {'/news {tag}Браво, {ID}! Перевод абсолютно точен. Набрано баллов: {scoreID}!'}},
                    {fa('TROPHY'), 'Назвать победителя', {
                        '/news {tag}Среди нас есть абсолютный знаток языков!',
                        '/news {tag}И его имя...',
                        '/news {tag}{ID}! Вы смогли верно перевести {scores} слов быстрее остальных конкурентов.',
                        '/news {tag}С гордостью объявляю, что {prize} отправляются в ваши карманы!',
                        '/news {tag}{ID}, мы ждем вас для торжественного вручения награды...',
                        '/news {tag}... прямо в ресепшене радиостанции г. {city}.'
                    }},
                    {fa('STOP'), 'Закончить эфир', {
                        '/news {tag}Ну что же, дорогие полиглоты, время программы истекло.',
                        '/news {tag}Мы отлично провели время и подтянули {language}ий язык.',
                        '/news {tag}Спасибо всем за активное участие, вы были великолепны!',
                        '/news {tag}С вами был {name}, {duty} студии г. {city}.',
                        '/news {tag}Изучайте языки, они стирают все границы!',
                        '/news {tag}До скорого включения!',
                        '/news {music}',
                        '/d [{tagCNN}] to [СМИ] Закончил передачу, освободил частоту.'
                    }}
                }
            },
            interv = {
                title = 'Интервью',
                tag = '[Интервью]: ',
                lines = {
                    {fa('PLAY'), 'Начать эфир', {
                        '/d [{tagCNN}] to [СМИ] Начинаю вещание. Прошу тишины на волне.',
                        '/news {music}',
                        '/news {tag}Добрый день, уважаемые слушатели нашего любимого штата {server}!',
                        '/news {tag}Сегодня за микрофоном {duty} из города {city} — {name}.',
                        '/news {tag}Мы запускаем всем известную рубрику "Интервью"!',
                        '/news {tag}Советую сделать приёмники погромче!',
                        '/news {tag}Сегодня на наши вопросы отвечает {interv_name}, занимающий должность {interv_position}!',
                        '/news {tag}Не будем тянуть время, давайте начинать!',
                        '/live'
                    }},
                    {fa('PAPER_PLANE'), 'Начать интервью', {'/l Итак, мы в прямом эфире! Добро пожаловать, {interv_name}! Рады вас видеть.'}},
                    {fa('CHEVRON_RIGHT'), 'Задать вопрос', {''}},
                    {fa('STOP'), 'Закончить эфир', {
                        '/news {tag}На этой ноте мы вынуждены прервать нашу увлекательную беседу.',
                        '/news {tag}Огромная благодарность гостю за ответы, а слушателям за внимание.',
                        '/news {tag}Напомню, сегодня на наши провокационные вопросы отвечал {interv_name}, {interv_position}!',
                        '/news {tag}Работу в эфире вел {name}, {duty} СМИ г. {city}.',
                        '/news {tag}Живите позитивно и радуйтесь каждому моменту!',
                        '/news {tag}До новых встреч на этой же радиочастоте!',
                        '/news {music}',
                        '/d [{tagCNN}] to [СМИ] Завершил интервью. Уступаю волну.'
                    }}
                }
            },
            sobes = {
                title = 'Собеседование',
                tag = '[Собеседование]: ',
                lines = {
                    {fa('PLAY'), 'Начать эфир', {
                        '/d [{tagCNN}] to [СМИ] Занял государственную волну вещания.',
                        '/news {music}',
                        '/news {tag}Уважаемые граждане прекрасного штата {server}, минуточку внимания!',
                        '/news {tag}Для вас вещает представитель г. {city} —',
                        '/news {tag}... {duty} {name}!',
                        '/news {tag}Хотите получать стабильный доход и раскрыть свой потенциал?',
                        '/news {tag}Мечтали ли вы когда-нибудь услышать свой голос на весь штат?',
                        '/news {tag}Тогда мы рады объявить об открытом собеседовании в наш радиоцентр г. {city}!',
                        '/news {tag}Мы гарантируем доброжелательный коллектив и лояльное руководство.',
                        '/news {tag}Критерии для вступления в наши ряды:',
                        '/news {tag}Паспорт, наличие медицинской карты, а также пакет актуальных лицензий.',
                        '/news {tag}Мы в поиске амбициозных и творческих личностей!',
                        '/news {tag}Наши условия: частые премии, отличная ЗП и все шансы для карьерного роста.',
                        '/news {tag}Если это про вас, незамедлительно выезжайте к нам!',
                        '/news {tag}Собеседование идет прямо сейчас, в главном холле радиоцентра г. {city}.',
                        '/news {tag}Ждем именно вашу кандидатуру!',
                        '/news {music}',
                        '/d [{tagCNN}] to [СМИ] Освободил государственную волну.'
                    }}
                }
            }
        }
    },
    vars = {
        prize = imgui.new.char[256]('1 млн'),
        scores = imgui.new.char[256]('5'),
        scoreID = imgui.new.char[256]('2'),
        ID = imgui.new.char[256](''),
        toID = imgui.new.char[256](''),
        phrase = imgui.new.char[256](''),
        time = imgui.new.char[256]('15'),
        language = imgui.new.char[256]('Английск'),
        math_example = imgui.new.char[256](''),
        math_result = '0',
        selected_ether = 'mathem',
        interv_name = imgui.new.char[256](''),
        interv_position = imgui.new.char[256](''),
        selected_question = imgui.new.int(0)
    },
    buffers = {
        name = imgui.new.char[256](cfg.ethers.name),
        duty = imgui.new.char[256](cfg.ethers.duty),
        tagCNN = imgui.new.char[256](cfg.ethers.tagCNN),
        city = imgui.new.char[256](cfg.ethers.city),
        server = imgui.new.char[256](cfg.ethers.server),
        music = imgui.new.char[256](cfg.ethers.music),
        delay = imgui.new.int(cfg.ethers.delay)
    },
    keys = {'mathem', 'capitals', 'greet', 'chemic', 'interpreter', 'interv', 'sobes'},
    names = {'Математика', 'Столицы', 'Приветы', 'Хим. элементы', 'Переводчики', 'Интервью', 'Собеседование'},
    interv_questions = {
        'Расскажите немного о себе. Как вас зовут и как вы пришли к этой профессии?',
        'Как долго вы работаете на вашей текущей должности?',
        'С каким настроением вы пришли сегодня к нам в студию?',
        'Не возникло ли проблем с дорогой к нашему радиоцентру?',
        'Как вы оцениваете свое финансовое положение? Есть ли авто или бизнес?',
        'Приоткройте завесу: на какой доход может рассчитывать сотрудник вашей сферы?',
        'Как вы расслабляетесь после работы? Какое у вас отношение к крепким напиткам?',
        'Свойственен ли вам азарт? Посещаете ли вы азартные заведения нашего штата?',
        'В завершение нашей беседы, хотите ли передать привет своим родным или друзьям?'
    }
}
local sobes = {
    id = imgui.new.int(-1),
    nick = 'Nick_Name',
    process = false,
    zakon = 'Неизвестно',
    sex = 'Неизвестно',
    lvl = 'Неизвестно',
    org = 'Неизвестно',
    narko = 'Неизвестно',
    povestka = 'Неизвестно'
}
local suggestion = {
    window = imgui.new.bool(false),
    matches = {},
    current_idx = 1,
    original_text = ""
}
local ether_control = {
    active = false,
    paused = false,
    thread = nil
}

local broadcast_action_state = { name = nil, index = nil }
local showRefusalPopup = imgui.new.bool(false)
local catch_ad_last_press = 0
local search_query = imgui.new.char[256]()
local main_tab = imgui.new.int(1)
local selected_ether_idx = imgui.new.int(0)
local editing_bind_index = 0
local autoBind = {{"/"}}
local key_buffers = {}
local ads = {}
local font = {}
local filtered_ads = {}
local keyBind = {}
local cheking_update = false
local last_search_text = ""
local changelog = ""
local editor_tab = 1
local exam_selected_tab = 1
local selected_week_offset = 0
local stats = {}
local fontReady = false
local font_path = config_path .. 'EagleSans-Regular.ttf'
local selected_stat_date_idx = imgui.new.int(0)
local tag = '{008080}[News Helper]: {C0C0C0}'

for k, v in pairs(cfg.binds) do
    local t = {}
    if type(v) == 'string' then
        for x in v:gmatch('(%d+)') do 
            local n = tonumber(x)
            if n and n > 0 and n < 256 then table.insert(t, n) end
        end
    elseif type(v) == 'number' then
        if v > 0 and v < 256 then table.insert(t, v) end
    elseif type(v) == 'table' then
        for _, val in ipairs(v) do
            local n = tonumber(val)
            if n and n > 0 and n < 256 then table.insert(t, n) end
        end
    end
    cfg.binds[k] = t
end
for name, keys in pairs(cfg.binds) do
    hotkey.RegisterHotKey(name, false, keys, function() 
        if sampIsChatInputActive() or isSampfuncsConsoleActive() then return end
        if name == 'menu' then
            if win.main[0] and anims.main_target then
                anims.main_target = false
            else
                if not win.main[0] then anims.main_alpha = 0 end
                win.main[0] = true
                anims.main_target = true
            end
        elseif name == 'helper' then
             if win.helper[0] and anims.helper_target then
                anims.helper_target = false
            else
                if not win.helper[0] then anims.helper_alpha = 0 end
                win.helper[0] = true
                anims.helper_target = true
            end
        end
    end)
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
	load_ads()
	load_stats()
	convert_old_ads()

    local current_date_check = os.date("%Y-%m-%d")
    if not stats[current_date_check] then
        stats[current_date_check] = {ads = 0, money = 0}
        save_stats()
    end

    autoBind = load_json(config_path .. 'autoBind.json')
    if type(autoBind) ~= 'table' or not autoBind[1] or type(autoBind[1]) ~= 'table' or not autoBind[1][1] then
        autoBind = {{"/"}} 
    end
    
    keyBind = load_json(config_path .. 'keyBind.json')
    keyBind = keyBind or {}
    
    if not doesDirectoryExist(config_path) then createDirectory(config_path) end

    if not cfg.settings then
        cfg.settings = cfg_default.settings
        save_config()
    else
        for k, v in pairs(cfg_default.settings) do
            if cfg.settings[k] == nil then cfg.settings[k] = v end
        end
    end
    if not cfg.binds then
        cfg.binds = cfg_default.binds
        save_config()
    end
    if not cfg.ethers then
        cfg.ethers = cfg_default.ethers
        save_config()
        ethers.data.settings = cfg.ethers
    end
    if not cfg.theme then
        cfg.theme = cfg_default.theme
        save_config()
    else
        for k, v in pairs(cfg.theme) do
            if type(v) == 'string' then
                if v:find('table:') then
                     cfg.theme[k] = cfg_default.theme[k]
                else
                     local c = {}
                     for x in v:gmatch('[^,]+') do table.insert(c, tonumber(x)) end
                     if #c == 4 then 
                        cfg.theme[k] = c 
                     else 
                        cfg.theme[k] = cfg_default.theme[k] 
                     end
                end
            elseif type(v) ~= 'table' then
                 cfg.theme[k] = cfg_default.theme[k]
            elseif type(v) == 'table' and #v ~= 4 then
                 cfg.theme[k] = cfg_default.theme[k]
            end
        end
        for k, v in pairs(cfg_default.theme) do
            if not cfg.theme[k] then cfg.theme[k] = v end
        end
        save_config()
    end
    
    imgui.StrCopy(ethers.buffers.name, cfg.ethers.name)
    imgui.StrCopy(ethers.buffers.duty, cfg.ethers.duty)
    imgui.StrCopy(ethers.buffers.tagCNN, cfg.ethers.tagCNN)
    imgui.StrCopy(ethers.buffers.city, cfg.ethers.city)
    imgui.StrCopy(ethers.buffers.server, cfg.ethers.server)
    imgui.StrCopy(ethers.buffers.music, cfg.ethers.music)
    ethers.buffers.delay[0] = cfg.ethers.delay

    sampRegisterChatCommand('rnh', function() 
        if win.main[0] and anims.main_target then
            anims.main_target = false
        else
            if not win.main[0] then anims.main_alpha = 0 end
            win.main[0] = true
            anims.main_target = true
        end
    end)

    if not doesFileExist(font_path) then
        fontReady = false
		cLog('У вас отсутствует шрифт! Начинаю скачивание..')
		downloadUrlToFile('https://github.com/Faiserx/News-Helper/raw/refs/heads/main/EagleSans-Regular.ttf', font_path, function(id, status)
			if status == dlstatus.STATUS_ENDDOWNLOADDATA then
				cLog('Шрифт успешно скачан!')
                fontReady = true
                thisScript():reload()
            elseif status == dlstatus.STATUS_ERROR then
                cLog('Ошибка скачивания шрифта! Скачайте напрямую по ссылке -> https://github.com/Faiserx/News-Helper/raw/refs/heads/main/EagleSans-Regular.ttf ...')
                cLog('После чего поместите файл по пути '..config_path)
                fontReady = true
			end
		end)
    else
        fontReady = true
	end
    
    while not fontReady do wait(0) end
    if not doesFileExist(font_path) then
        cLog('Без шрифта запуск невозможен!')
        thisScript():unload()
    end
    update_search()

	while not isSampAvailable() or not sampIsLocalPlayerSpawned() do wait(10000) end
	notif('success', 'News Helper', u8:decode('Скрипт загружен. Активация /rnh'), 5000)

    while true do
        wait(0)
        local now_date = os.date("%Y-%m-%d")
        if now_date ~= current_date_check then
            current_date_check = now_date
            if not stats[current_date_check] then
                stats[current_date_check] = {ads = 0, money = 0}
                save_stats()
                selected_stat_date_idx[0] = 0
            end
        end

        if cfg.binds.catchAd and type(cfg.binds.catchAd) == 'table' and #cfg.binds.catchAd > 0 and not sampIsChatInputActive() and not isSampfuncsConsoleActive() then
            local is_held = true
            for _, k in ipairs(cfg.binds.catchAd) do
                if not isKeyDown(k) then
                    is_held = false
                    break
                end
            end
            
            if is_held then
                if catch_ad_last_press == 0 or (os.clock() - catch_ad_last_press > 0.5) then
                    sampSendChat('/newsredak')
                    catch_ad_last_press = os.clock()
                end
            else
                catch_ad_last_press = 0
            end
        end

        if update_state then
            downloadUrlToFile('https://raw.githubusercontent.com/Faiserx/News-Helper/refs/heads/main/News%20Helper.lua', thisScript().path, function(id, status)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    notif('success', 'News Helper', u8:decode('Скрипт успешно обновлен, перезагружаюсь...'), 2000)
                    thisScript():reload()
                elseif status == dlstatus.STATUS_ERROR then
                    notif('error', 'News Helper', u8:decode('Не удалось обновить скрипт!'), 5000)
                    sampAddChatMessage(u8:decode(tag .. 'Не удалось обновить скрипт! Попробуйте еще раз. Если проблема сохранится - обратитесь к разработчику!'), 0x008080)
                end
            end)
            break
        end
    end
end

imgui.OnInitialize(function()
    apply_style()
    local io = imgui.GetIO()
    io.IniFilename = nil
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = imgui.new.ImWchar[3](fa.min_range, fa.max_range, 0)
    if doesFileExist(font_path) then
        local glyph_ranges = io.Fonts:GetGlyphRangesCyrillic()
        for i = 10, 24, 2 do
            config.MergeMode = false
            font[i] = io.Fonts:AddFontFromFileTTF(font_path, i, nil, glyph_ranges)
            config.MergeMode = true
            io.Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), i, config, iconRanges)
        end
    else
        config.MergeMode = true
        io.Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85('solid'), 14, config, iconRanges)
    end
end)

local is_first_frame = true
imgui.OnFrame(
    function() return is_first_frame end,
    function()
        is_first_frame = false
        imgui.HideCursor = true
    end
)

function ethersSave()
    cfg.ethers.name = ffi.string(ethers.buffers.name)
    cfg.ethers.duty = ffi.string(ethers.buffers.duty)
    cfg.ethers.tagCNN = ffi.string(ethers.buffers.tagCNN)
    cfg.ethers.city = ffi.string(ethers.buffers.city)
    cfg.ethers.server = ffi.string(ethers.buffers.server)
    cfg.ethers.music = ffi.string(ethers.buffers.music)
    cfg.ethers.delay = ethers.buffers.delay[0]
    save_config()
end
function updateThemeFromAccent(accent)
    local r, g, b, a = accent[1], accent[2], accent[3], accent[4]
    cfg.theme.Accent = {r, g, b, a}
    cfg.theme.Button = {r, g, b, 0.7}
    cfg.theme.ButtonHovered = {math.min(1, r * 1.2), math.min(1, g * 1.2), math.min(1, b * 1.2), 0.9}
    cfg.theme.ButtonActive = {r * 0.8, g * 0.8, b * 0.8, 1.0}
    cfg.theme.Header = {r, g, b, 0.7}
    cfg.theme.Border = {r * 0.5, g * 0.5, b * 0.5, 0.6}
    cfg.theme.FrameBg = {r * 0.1, g * 0.1, b * 0.1, 1.0}
    cfg.theme.FrameBgHovered = {r * 0.2, g * 0.2, b * 0.2, 1.0}
    cfg.theme.FrameBgActive = {r * 0.3, g * 0.3, b * 0.3, 1.0}
    
    cfg.theme.WindowBg = {r * 0.05 + 0.05, g * 0.05 + 0.05, b * 0.05 + 0.07, 0.98}
    cfg.theme.ChildBg = {r * 0.08 + 0.06, g * 0.08 + 0.06, b * 0.08 + 0.08, 0.4}
    cfg.theme.PopupBg = {r * 0.1 + 0.05, g * 0.1 + 0.05, b * 0.1 + 0.07, 1.0}
    cfg.theme.TitleBg = {r * 0.1 + 0.05, g * 0.1 + 0.05, b * 0.1 + 0.07, 1.0}
    
    apply_style()
    save_config()
end
function resetTheme()
    cfg.theme = {}
    for k, v in pairs(cfg_default.theme) do
        if type(v) == 'table' then
            cfg.theme[k] = {v[1], v[2], v[3], v[4]}
        else
            cfg.theme[k] = v
        end
    end
    apply_style()
    save_config()
end
local function idToNick(val)
    local num = tonumber(val)
    if num and num >= 0 and sampIsPlayerConnected(num) then
        local nick = sampGetPlayerNickname(num)
        return nick and nick:gsub("_", " ") or val
    end
    return val
end

function parseTags(str, vars)
    str = str:gsub('{tagCNN}', ethers.data.settings.tagCNN)
    str = str:gsub('{city}', ethers.data.settings.city)
    str = str:gsub('{server}', ethers.data.settings.server)
    str = str:gsub('{music}', ethers.data.settings.music)
    str = str:gsub('{duty}', ethers.data.settings.duty)
    str = str:gsub('{name}', ethers.data.settings.name)
    str = str:gsub('{prize}', ffi.string(vars.prize))
    str = str:gsub('{scores}', ffi.string(vars.scores))
    str = str:gsub('{scoreID}', ffi.string(vars.scoreID))
    str = str:gsub('{ID}', idToNick(ffi.string(vars.ID)))
    str = str:gsub('{toID}', idToNick(ffi.string(vars.toID)))
    str = str:gsub('{phrase}', ffi.string(vars.phrase))
    str = str:gsub('{time}', ffi.string(vars.time))
    str = str:gsub('{language}', ffi.string(vars.language))
    str = str:gsub('{interv_name}', ffi.string(vars.interv_name))
    str = str:gsub('{interv_position}', ffi.string(vars.interv_position))
    if vars.selected_ether and ethers.data.events[vars.selected_ether] then
        str = str:gsub('{tag}', ethers.data.events[vars.selected_ether].tag)
    end
    return str
end
function formatNumber(amount)
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if (k==0) then
            break
        end
    end
    return formatted
end
function ethersPlay(lines, vars, callback)
    if ether_control.active then
        sampAddChatMessage(tag .. 'Дождитесь окончания действия или остановите его!', -1)
        return
    end
    
    ether_control.active = true
    ether_control.paused = false
    
    ether_control.thread = lua_thread.create(function() 
        for _, line in ipairs(lines) do
            while ether_control.paused do wait(100) if not ether_control.active then break end end
            if not ether_control.active then break end
            
            local text = parseTags(line, vars)
            if #text > 0 then
                sampSendChat(u8:decode(text))
            end

            local wait_time = ethers.data.settings.delay * 1000
            local elapsed = 0
            while elapsed < wait_time do
                wait(100)
                elapsed = elapsed + 100
                if not ether_control.active then break end
                while ether_control.paused do wait(100) if not ether_control.active then break end end
            end
            if not ether_control.active then break end
        end
        
        ether_control.active = false
        ether_control.paused = false
        if callback then callback() end
    end)
end
function save_config()
    if not doesDirectoryExist(config_path) then createDirectory(config_path) end
    local file, err = io.open(config_path .. 'settings.json', 'w')
    if file then
        local result, encoded = pcall(encodeJson, cfg)
        if result then
            file:write(encoded)
        end
        file:close()
    end
end

addEventHandler('onSendPacket', function(id, bs)
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        local pType = raknetBitStreamReadInt8(bs)
        if pType == 18 then
            local len = raknetBitStreamReadInt16(bs)
            local text = raknetBitStreamReadString(bs, len)
            if text:find('^arizona%-cef%-dialogs|(.+)$') then
                local json = text:match('^arizona%-cef%-dialogs|(.+)$')
                if json then
                    local ok, data = pcall(decodeJson, json)
                    if ok and data then
                        pending_cef[tonumber(data.requestId)] = {
                            received = true,
                            value = data.value,
                        }
                    end
                end
                return false
            end
        end
    end
end)
function cefQuery(code, timeout)
    if type(code) ~= 'string' then return end
    timeout = timeout or 500
    cef_seq = cef_seq + 1
    local requestId = cef_seq

    local code_fmt = string.format([=[
var value;
try { value = (function () { %s })(); } catch (e) { value = null; }
if (!window.cef) return;
var data = { requestId: %d, value: value };
window.cef.SendMessage('arizona-cef-dialogs|' + JSON.stringify(data), 0);
]=], code, requestId)

    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code_fmt)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code_fmt)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)

    if coroutine.running() then
        local deadline = os.clock() + timeout / 1000
        while not (pending_cef[requestId] and pending_cef[requestId].received) and os.clock() < deadline do wait(0) end
        local value = pending_cef[requestId] and pending_cef[requestId].value or nil
        pending_cef[requestId] = nil
        return value
    end
    return nil
end
local orig_sampGetCurrentDialogEditboxText = sampGetCurrentDialogEditboxText
sampGetCurrentDialogEditboxText = function()
    local text = nil
    if coroutine.running() then
        pcall(function()
            text = cefQuery([[
                var d = document.querySelector('.dialog');
                if (!d) return null;
                var i = d.querySelector('input.dialog-input__field');
                return i ? i.value : null;
            ]], 100)
        end)
    end
    if type(text) == 'string' then return text end
    return orig_sampGetCurrentDialogEditboxText()
end
local orig_sampSetCurrentDialogEditboxText = sampSetCurrentDialogEditboxText
sampSetCurrentDialogEditboxText = function(text)
    local code = string.format("(() => {var d = document.querySelector('.dialog');if (!d) return;var i = d.querySelector('input.dialog-input__field');if (!i) return;i.value = %q;})()", tostring(text))
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end
function sampGetDialogInfoPtr()
    return memory.getuint32(getModuleHandle("samp.dll") + 0x26E898, true)
end
function setDialogCursorPos(pos)
    local code = string.format("(() => {var d = document.querySelector('.dialog');if (!d) return;var i = d.querySelector('input.dialog-input__field');if (!i) return;i.setSelectionRange(%d, %d);})()", pos, pos)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)

    pcall(function()
        local m_pEditbox = memory.getuint32(sampGetDialogInfoPtr() + 0x24, true)
        memory.setuint8(m_pEditbox + 0x119, pos, true)
        memory.setuint8(m_pEditbox + 0x11E, pos, true)
    end)
end
function getDialogCursorPos()
    local pos = 0
    pcall(function()
        local m_pEditbox = memory.getuint32(sampGetDialogInfoPtr() + 0x24, true)
        pos = memory.getuint8(m_pEditbox + 0x119, true)
    end)
    
    if pos == 0 then
        local text = sampGetCurrentDialogEditboxText()
        if text then pos = string.len(u8:encode(text)) end
    end
    return pos
end

local main_frame = imgui.OnFrame(
    function() return win.main[0] end,
    function(player)
        if anims.main_target then
            if anims.main_alpha < 1.0 then
                anims.main_alpha = anims.main_alpha + (1.0 - anims.main_alpha) * 0.12
                if anims.main_alpha > 0.995 then anims.main_alpha = 1.0 end
            end
        else
            if anims.main_alpha > 0.0 then
                anims.main_alpha = anims.main_alpha - (0.01 + anims.main_alpha) * 0.15
                if anims.main_alpha < 0.01 then 
                    anims.main_alpha = 0
                    win.main[0] = false
                end
            end
        end
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, anims.main_alpha)
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(900, 450), imgui.Cond.FirstUseEver)
        imgui.Begin('News Helper', win.main, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize)

        imgui.BeginGroup()

            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.12, 0.12, 0.14, 0.9))
            imgui.BeginChild('LeftMenu', imgui.ImVec2(200, 0), true)
                imgui.Spacing()
                if font[24] then
                    imgui.PushFont(font[24])
                    local txt = "News Helper"
                    local title_w = imgui.CalcTextSize(txt).x
                    imgui.SetCursorPosX((200 - title_w)/2)
                    imgui.TextColored(imgui.ImVec4(0.48, 0.58, 0.98, 1.00), txt)
                    imgui.PopFont()
                else
                    imgui.Text("News Helper")
                end
                if imgui.IsItemClicked(2) then thisScript():reload() end
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()
                imgui.CustomMenu(tabs_names, main_tab, imgui.ImVec2(180, 40))
            imgui.EndChild()
            imgui.PopStyleColor()

        imgui.EndGroup()
        
        imgui.SameLine()
        
        imgui.BeginGroup()
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0, 0, 0, 0))
            imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
            imgui.BeginChild('Content', imgui.ImVec2(0, -1), true)
                if anims.content_alpha < 1.0 then anims.content_alpha = anims.content_alpha + (1.0 - anims.content_alpha) * 0.2 end
                imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, anims.content_alpha * anims.main_alpha)
                imgui.SetCursorPosY(imgui.GetCursorPosY() - (1.0 - anims.content_alpha) * 15)

                local current_tab = main_tab[0]
                if current_tab == 1 then
                    if font[22] then imgui.PushFont(font[22]) end
                    imgui.TextCenter("Главная")
                    if font[22] then imgui.PopFont() end
                    imgui.SetCursorPosY(imgui.GetCursorPosY() + 11)
                    imgui.Separator()
                    if font[18] then imgui.PushFont(font[18]) end
                    imgui.TextWrapped('Помощник для сотрудников СМИ\n\nВаш персональный ассистент, который делает работу в редакции проще, не нарушая игрового баланса.\nВажно: Это инструмент поддержки, а не автоматизации. Я выступаю за честную игру, поэтому скрипт не выполняет функции бота и требует активного участия игрока.\n\nЕсли у вас есть предложения или идеи по улучшению скрипта, пожалуйста, свяжитесь со мной в личных сообщениях.')
                    if imgui.LoaderButton(cheking_update, 'Проверить обновления', imgui.ImVec2(225,30)) then
                        check_update()
                    end
                    imgui.SameLine()
                    if update_found then
                        if imgui.Button('Обновить', imgui.ImVec2(225,30)) then
                            update_state = true
                        end
                        imgui.TextDisabled('Список изменений:\n'..changelog)
                    end
                    if font[18] then imgui.PopFont() end
                elseif current_tab == 2 then
                    if font[18] then imgui.PushFont(font[18]) end
                    imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
                    imgui.BeginChild('EditorTabs', imgui.ImVec2(0, 45), false)
                        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(15, 0))
                        imgui.SetCursorPosY(imgui.GetCursorPosY() + 3)
                        imgui.SetCursorPosX(imgui.GetWindowWidth() / 2/2-20)
                        if imgui.HeaderButton(editor_tab == 1, fa('CLOCK') .. " Мои объявления") then editor_tab = 1 end
                        imgui.SameLine()
                        if imgui.HeaderButton(editor_tab == 2, fa('WAND_MAGIC_SPARKLES') .. " Автозамена") then 
                            editor_tab = 2 
                            editing_bind_index = 0
                            imgui.StrCopy(autobind_buffers.new_bind_key, "")
                            imgui.StrCopy(autobind_buffers.new_bind_value, "")
                        end
                        imgui.SameLine()
                        if imgui.HeaderButton(editor_tab == 3, fa('KEYBOARD') .. " Клавиши") then editor_tab = 3 end
                        imgui.PopStyleVar()
                    imgui.EndChild()
                    imgui.Separator()

                    if editor_tab == 1 then
                        imgui.PushItemWidth(300)
                        if imgui.InputTextWithHint('##Search', 'Поиск...', search_query, 256) then
                            local txt = ffi.string(search_query)
                            if txt ~= last_search_text then
                                last_search_text = txt
                                update_search()
                            end
                        end
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        if imgui.Button('Очистить') then
                            search_query[0] = 0
                            last_search_text = ""
                            update_search()
                        end
                        imgui.Separator()
                        imgui.BeginChild('AdsList', imgui.ImVec2(0, -1), false)
                             for i, ad in ipairs(filtered_ads) do
                                imgui.PushIDInt(i)
                                if imgui.Selectable(string.format("[%d] %s", i, ad.text), false) then
                                    local real_idx = 0
                                    for k, v in ipairs(ads) do if v == ad then real_idx = k break end end
                                    edit_modal.index = real_idx
                                    imgui.StrCopy(edit_modal.original, ad.text)
                                    imgui.StrCopy(edit_modal.edited, ad.my_text)
                                    edit_modal.state[0] = true
                                end
                                if imgui.IsItemHovered() then
                                    imgui.Hint('my_text', ad.my_text, 0.3)
                                end
                                imgui.PopID()
                            end
                        imgui.EndChild()
                    elseif editor_tab == 2 then
                        imgui.BeginChild('editor tab 2', imgui.ImVec2(0, -10), false)
                            imgui.SetCursorPosX(10)
                            imgui.Text('Специальный символ:')
                            imgui.SameLine()
                            imgui.PushItemWidth(30)
                            
                            if not autoBind[1] then autoBind[1] = {"/"} end
                            
                            imgui.StrCopy(autobind_buffers.replace_char_buffer, autoBind[1][1] or "/")
                            if imgui.InputText('##NH_SpecChar', autobind_buffers.replace_char_buffer, 255) then
                                autoBind[1][1] = ffi.string(autobind_buffers.replace_char_buffer):gsub('%%', '')
                                save_json(config_path .. 'autoBind.json', autoBind)
                            end
                            imgui.PopItemWidth()
                            imgui.SameLine()
                            imgui.RenderText('{FFFFFF99}(?)')
                            if imgui.IsItemHovered() then
                                imgui.SetTooltip('Символ, с которого начинается команда для авто-замены')
                            end

                            imgui.Spacing()
                            imgui.Separator()
                            imgui.Spacing()

                            imgui.Text(editing_bind_index == 0 and 'Добавить замену:' or 'Редактирование #'..editing_bind_index..':')
                            
                            imgui.PushItemWidth(100)
                            imgui.InputTextWithHint('##NH_AddKey', 'Сокращение', autobind_buffers.new_bind_key, 255)
                            imgui.PopItemWidth()
                            imgui.SameLine()
                            imgui.PushItemWidth(250)
                            imgui.InputTextWithHint('##NH_AddVal', 'Полный текст', autobind_buffers.new_bind_value, 255)
                            imgui.PopItemWidth()
                            imgui.SameLine()
                            
                            if editing_bind_index == 0 then
                                if imgui.Button('Добавить', imgui.ImVec2(80, 25)) then
                                    local key = ffi.string(autobind_buffers.new_bind_key)
                                    local val = ffi.string(autobind_buffers.new_bind_value)
                                    if key ~= "" and val ~= "" then
                                        table.insert(autoBind, {key, val})
                                        imgui.StrCopy(autobind_buffers.new_bind_key, "")
                                        imgui.StrCopy(autobind_buffers.new_bind_value, "")
                                        save_json(config_path .. 'autoBind.json', autoBind)
                                    end
                                end
                            else
                                if imgui.Button('Сохранить', imgui.ImVec2(80, 25)) then
                                    local key = ffi.string(autobind_buffers.new_bind_key)
                                    local val = ffi.string(autobind_buffers.new_bind_value)
                                    if key ~= "" and val ~= "" and autoBind[editing_bind_index] then
                                        autoBind[editing_bind_index] = {key, val}
                                        editing_bind_index = 0
                                        imgui.StrCopy(autobind_buffers.new_bind_key, "")
                                        imgui.StrCopy(autobind_buffers.new_bind_value, "")
                                        save_json(config_path .. 'autoBind.json', autoBind)
                                    end
                                end
                                imgui.SameLine()
                                if imgui.Button('Отмена', imgui.ImVec2(80, 25)) then
                                    editing_bind_index = 0
                                    imgui.StrCopy(autobind_buffers.new_bind_key, "")
                                    imgui.StrCopy(autobind_buffers.new_bind_value, "")
                                end
                            end

                            imgui.Spacing()
                            imgui.TextCenter('Список авто-замен')
                            imgui.Spacing()

                            imgui.BeginChild('AutoBindList', imgui.ImVec2(0, 200), true)
                                if autoBind then
                                    local to_remove = nil
                                    for i = 2, #autoBind do
                                        local item = autoBind[i]
                                        if item and type(item) == 'table' then
                                            local key = item[1] or "?"
                                            local val = item[2] or "?"
                                            local display_text = string.format("[%s] -> %s", key, val)
                                            
                                            imgui.PushIDInt(i)
                                            if imgui.Selectable(display_text, editing_bind_index == i) then
                                                editing_bind_index = i
                                                imgui.StrCopy(autobind_buffers.new_bind_key, key)
                                                imgui.StrCopy(autobind_buffers.new_bind_value, val)
                                            end

                                            if imgui.BeginPopupContextItem() then
                                                if imgui.Selectable("Удалить") then
                                                    to_remove = i
                                                end
                                                imgui.EndPopup()
                                            end
                                            imgui.PopID()
                                        end
                                    end
                                    
                                    if to_remove then
                                        table.remove(autoBind, to_remove)
                                        if editing_bind_index == to_remove then
                                            editing_bind_index = 0
                                            imgui.StrCopy(autobind_buffers.new_bind_key, "")
                                            imgui.StrCopy(autobind_buffers.new_bind_value, "")
                                        elseif editing_bind_index > to_remove then
                                            editing_bind_index = editing_bind_index - 1
                                        end
                                        save_json(config_path .. 'autoBind.json', autoBind)
                                    end
                                end
                            imgui.EndChild()
                            imgui.TextDisabled("ПКМ по элементу для удаления, ЛКМ для редактирования")
                        imgui.EndChild()
                    elseif editor_tab == 3 then
                            imgui.BeginChild('HotkeysContent', imgui.ImVec2(0, 0), false)
                                imgui.Text('Добавить новую горячую клавишу:')
                                imgui.Spacing()
                                
                                hotkey_buffer = hotkey_buffer or {}
                                if not hotkey.List['NH_NewBind'] then
                                    hotkey.RegisterHotKey('NH_NewBind', false, hotkey_buffer)
                                end
                                
                                imgui.Text('Клавиши:')
                                imgui.SameLine()
                                if hotkey.ShowHotKey('NH_NewBind', imgui.ImVec2(100, 25)) then
                                    hotkey_buffer = hotkey.List['NH_NewBind'].keys
                                end
                                
                                imgui.SameLine()
                                imgui.Text('Действие:')
                                imgui.SameLine()
                                imgui.PushItemWidth(250)
                                imgui.InputTextWithHint('##NH_NewBindValue', 'Текст для вставки', autobind_buffers.new_hotkey_bind_value, 255)
                                imgui.PopItemWidth()
                                
                                imgui.SameLine()
                                if imgui.Button('Добавить', imgui.ImVec2(80, 25)) then
                                    local keys = hotkey.List['NH_NewBind'].keys
                                    local val = ffi.string(autobind_buffers.new_hotkey_bind_value)
                                    if #keys > 0 and val ~= "" then
                                        table.insert(keyBind, {keys, val})
                                        hotkey.List['NH_NewBind'].keys = {}
                                        imgui.StrCopy(autobind_buffers.new_hotkey_bind_value, "")
                                        save_json(config_path .. 'keyBind.json', keyBind)
                                    end
                                end
    
                                imgui.Spacing()
                                imgui.Separator()
                                imgui.Spacing()
                                imgui.TextCenter('Ваши горячие клавиши')
                                imgui.Spacing()
    
                                imgui.BeginChild('HotkeysList', imgui.ImVec2(0, 0), true)
                                for i, btn in ipairs(keyBind) do
                                    imgui.PushIDInt(i)
                                    local bind_name = 'NH_Bind_'..i
                                    if not hotkey.List[bind_name] then
                                        hotkey.RegisterHotKey(bind_name, false, btn[1] or {})
                                    end
                                    
                                    if hotkey.ShowHotKey(bind_name, imgui.ImVec2(120, 25)) then
                                        keyBind[i][1] = hotkey.List[bind_name].keys
                                        save_json(config_path .. 'keyBind.json', keyBind)
                                    end
                                    
                                    imgui.SameLine()
                                    imgui.PushItemWidth(300)
                                    
                                    if not key_buffers[i] then key_buffers[i] = imgui.new.char[256](btn[2] or "") end
    
                                    if imgui.InputText('##NH_Val_'..i, key_buffers[i], 255) then
                                        keyBind[i][2] = ffi.string(key_buffers[i])
                                        save_json(config_path .. 'keyBind.json', keyBind)
                                    end
                                    imgui.PopItemWidth()
                                    
                                    imgui.SameLine()
                                    if imgui.Button(fa('TRASH_CAN') .. '##NH_Del_'..i, imgui.ImVec2(30, 25)) then
                                        table.remove(keyBind, i)
                                        table.remove(key_buffers, i)
                                        hotkey.RemoveHotKey(bind_name)
                                        save_json(config_path .. 'keyBind.json', keyBind)
                                        imgui.PopID()
                                        break
                                    end
                                    
                                    imgui.PopID()
                                end
                                imgui.EndChild()
                            imgui.EndChild()
                    end
                    if font[18] then imgui.PopFont() end

                elseif current_tab == 3 then
                    if font[20] then imgui.PushFont(font[20]) end
                    imgui.TextCenter(fa('CHART_BAR') .. " Статистика")
                    if font[20] then imgui.PopFont() end
                    imgui.Separator()
                    local today_ts = os.time()
                    local d_info = os.date("*t", today_ts)
                    local days_since_mon = (d_info.wday == 1 and 6 or d_info.wday - 2) 
                    local monday_ts = today_ts - (days_since_mon * 86400) + (selected_week_offset * 7 * 86400)
                    local sunday_ts = monday_ts + (6 * 86400)
                    
                    imgui.Spacing()
                    imgui.SetCursorPosX((600 - 200) / 2) 
                    
                    if imgui.Button("<##prev", imgui.ImVec2(30, 0)) then selected_week_offset = selected_week_offset - 1 end
                    imgui.SameLine(0, 15)
                    
                    local week_str = os.date("%d.%m.%Y", monday_ts) .. " - " .. os.date("%d.%m.%Y", sunday_ts)
                    imgui.Text(week_str)
                    
                    imgui.SameLine(0, 15)
                    if imgui.Button(">##next", imgui.ImVec2(30, 0)) then 
                        if selected_week_offset < 0 then selected_week_offset = selected_week_offset + 1 end
                    end
                    
                    if selected_week_offset ~= 0 then
                        imgui.SameLine()
                        if imgui.Button("Текущая", imgui.ImVec2(65, 0)) then selected_week_offset = 0 end
                    end
                    imgui.Spacing()

                    local graphDataAds = {}
                    local graphDataMoney = {}
                    local wday_names = {"Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"}
                    local max_ads, max_money = 0, 0
                    
                    for i = 0, 6 do
                        local d = monday_ts + i * 86400
                        local d_str = os.date("%Y-%m-%d", d)

                        local val_ads = stats[d_str] and stats[d_str].ads or 0
                        local val_money = stats[d_str] and stats[d_str].money or 0
                        
                        table.insert(graphDataAds, {day = wday_names[i+1], full_date = d_str, value = val_ads, unit = 'шт.'})
                        table.insert(graphDataMoney, {day = wday_names[i+1], full_date = d_str, value = val_money, unit = '$'})
                        
                        if val_ads > max_ads then max_ads = val_ads end
                        if val_money > max_money then max_money = val_money end
                    end
                    
                    if max_ads == 0 then max_ads = 10 end
                    if max_money == 0 then max_money = 10000 end

                    local p = imgui.GetCursorScreenPos()
                    local graphWidth = 285
                    local graphHeight = 150
                    
                    drawActivityGraph(p.x + 5, p.y + 5, graphWidth, graphHeight, graphDataAds, max_ads * 1.2, imgui.ImVec4(0.2, 0.6, 1.0, 1.0), "Объявления (шт.)")
                    drawActivityGraph(p.x + graphWidth + 15, p.y + 5, graphWidth, graphHeight, graphDataMoney, max_money * 1.2, imgui.ImVec4(0.2, 0.8, 0.4, 1.0), "Доход ($)")
                    
                    imgui.Dummy(imgui.ImVec2(0, graphHeight + 10))
                    imgui.Separator()
                    
                    if font[18] then imgui.PushFont(font[18]) end
                    imgui.Text("Детальная статистика выбранного дня")
                    if font[18] then imgui.PopFont() end
                    imgui.Spacing()
                    
                    imgui.BeginChild("DayStatsChild", imgui.ImVec2(0, 0), true)
                        local dates = {}
                        for date, _ in pairs(stats) do table.insert(dates, date) end
                        table.sort(dates, function(a, b) return a > b end) 
                        if #dates == 0 then table.insert(dates, os.date("%Y-%m-%d", today_ts)) end
                        
                        local dates_cstr = {}
                        for _, d in ipairs(dates) do table.insert(dates_cstr, d) end
                        local dates_char = imgui.new['const char*'][#dates_cstr](dates_cstr)

                        imgui.Text("Выберите день:")
                        imgui.SameLine(0, 10)
                        imgui.PushItemWidth(140)
                        imgui.Combo("##stats_date", selected_stat_date_idx, dates_char, #dates_cstr)
                        imgui.PopItemWidth()
                        
                        local sel_date = dates[selected_stat_date_idx[0] + 1]
                        local day_stats = stats[sel_date] or {ads = 0, money = 0}
                        imgui.Separator()
                        imgui.Columns(2, "stats_columns", false)
                        
                        imgui.Text("Отредактировано:")
                        if font[18] then imgui.PushFont(font[18]) end
                        imgui.TextColored(imgui.ImVec4(0.2, 0.8, 0.2, 1), formatNumber(day_stats.ads or 0) .. " шт.")
                        if font[18] then imgui.PopFont() end
                        
                        imgui.NextColumn()
                        
                        imgui.Text("Заработано денег:")
                        if font[18] then imgui.PushFont(font[18]) end
                        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.2, 1), formatNumber(day_stats.money or 0) .. " $")
                        if font[18] then imgui.PopFont() end
                        
                        imgui.Columns(1)
                    imgui.EndChild()
                elseif current_tab == 4 then
                    local selected_key = ethers.vars.selected_ether
                    local ether = ethers.data.events[selected_key]

                    if font[18] then imgui.PushFont(font[18]) end
                    local selected = ethers.names[selected_ether_idx[0] + 1] or "Не выбран"
                    imgui.TextCenter(fa('HEADSET') .. " Текущий эфир: " .. selected)
                    imgui.Separator()

                    imgui.SetCursorPosY(imgui.GetCursorPosY() + 10)
                    imgui.BeginChild('EtherTabs', imgui.ImVec2(0, 45), false)
                        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(7, 0))
                        for i, key in ipairs(ethers.keys) do
                            
                            if imgui.HeaderButton(ethers.vars.selected_ether == key, ethers.names[i] .. "##ether_tab") then
                                ethers.vars.selected_ether = key
                                selected_ether_idx[0] = i - 1
                            end
                            
                            imgui.SameLine()
                        end
                        
                        imgui.PopStyleVar()
                    imgui.EndChild()
                    
                    imgui.BeginChild('EtherMainContent', imgui.ImVec2(0, 0), false)
                        if selected_key ~= 'sobes' then
                            imgui.Columns(2, 'ether_main_columns', false)
                            imgui.SetColumnWidth(0, 270)
                        end

                        if selected_key ~= 'sobes' then
                            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.1, 0.1, 0.1, 0.3))
                            imgui.BeginChild('EtherVarsFrame', imgui.ImVec2(260, 0), true)
                                imgui.TextDisabled('ПЕРЕМЕННЫЕ')
                                imgui.Separator()
                                imgui.Spacing()
                            
                            local function EtherInput(label, buf)
                                imgui.Text(label)
                                imgui.PushItemWidth(-1)
                                imgui.InputText('##' .. label, buf, 256)
                                imgui.PopItemWidth()
                                imgui.Spacing()
                            end
                            
                                if selected_key ~= 'interv' then
                                    EtherInput('ID/Ник Победителя', ethers.vars.ID)
                                    EtherInput('Сумма приза', ethers.vars.prize)
                                    
                                    if selected_key ~= 'greet' then
                                        EtherInput('Баллы для победы', ethers.vars.scores)
                                        EtherInput('Текущие баллы', ethers.vars.scoreID)
                                    end
                                end
                            
                            if selected_key == 'greet' then
                                EtherInput('ID получателя', ethers.vars.toID)
                                EtherInput('Время эфира', ethers.vars.time)
                            elseif selected_key == 'interpreter' then
                                EtherInput('Язык эфира', ethers.vars.language)
                                imgui.Hint('niznayu','Введите без окончания (к примеру Французск, в эфире оно подставится само)')
                            elseif selected_key == 'interv' then
                                EtherInput('Имя гостя', ethers.vars.interv_name)
                                EtherInput('Должность', ethers.vars.interv_position)
                            elseif selected_key == 'sobes' then
                                imgui.TextDisabled('Жми! Жми!!')
                            end
                            imgui.EndChild()
                            imgui.PopStyleColor()

                            if selected_key ~= 'sobes' then
                                imgui.NextColumn()
                            end
                        end

                        if ether then
                            imgui.BeginChild('EtherActionsFrame', imgui.ImVec2(0, 0), false)
                            imgui.SetCursorPosY(imgui.GetCursorPosY()+7)
                                imgui.TextDisabled('УПРАВЛЕНИЕ ЭФИРОМ')
                                imgui.Separator()
                                imgui.Spacing()

                                imgui.Columns(2, 'ether_ctrl_btns', false)
                                local pp_icon = ether_control.paused and fa('PLAY') or fa('PAUSE')
                                local pp_text = ether_control.paused and 'Продолжить' or 'Пауза'
                                if imgui.Button(pp_icon .. '  ' .. pp_text, imgui.ImVec2(-1, 27)) then
                                    if ether_control.active then
                                        ether_control.paused = not ether_control.paused
                                    else
                                        sampAddChatMessage(tag .. 'Нет активного эфира!', -1)
                                    end
                                end
                                imgui.NextColumn()
                                if imgui.Button(fa('STOP') .. '  СТОП', imgui.ImVec2(-1, 27)) then
                                    if ether_control.active then
                                        ether_control.active = false
                                        ether_control.paused = false
                                        sampAddChatMessage(tag .. 'Эфир принудительно остановлен!', -1)
                                        
                                        broadcast_action_state.name = nil
                                        broadcast_action_state.index = nil
                                    end
                                end
                                imgui.Columns(1)
                                imgui.Spacing()
                                imgui.Separator()
                                imgui.Spacing()

                                if selected_key == 'sobes' then
                                    local is_start_loading = broadcast_action_state.name == ethers.vars.selected_ether and broadcast_action_state.index == 'start'
                                    if imgui.LoaderButton(is_start_loading, fa('PLAY') .. '  Начать эфир', imgui.ImVec2(-1, 27)) then
                                        broadcast_action_state.name = ethers.vars.selected_ether
                                        broadcast_action_state.index = 'start'
                                        ethersPlay(ether.lines[1][3], ethers.vars, function() 
                                            broadcast_action_state.name = nil 
                                            broadcast_action_state.index = nil 
                                        end)
                                    end
                                elseif selected_key == 'interv' then
                                    imgui.Columns(2, 'quick_btns', false)
                                    local is_start_loading = broadcast_action_state.name == ethers.vars.selected_ether and broadcast_action_state.index == 'start'
                                    if imgui.LoaderButton(is_start_loading, fa('PLAY') .. '  Начать эфир', imgui.ImVec2(-1, 27)) then
                                        broadcast_action_state.name = ethers.vars.selected_ether
                                        broadcast_action_state.index = 'start'
                                        ethersPlay(ether.lines[1][3], ethers.vars, function() 
                                            broadcast_action_state.name = nil 
                                            broadcast_action_state.index = nil 
                                        end)
                                    end
                                    imgui.NextColumn()
                                    local is_stop_loading = broadcast_action_state.name == ethers.vars.selected_ether and broadcast_action_state.index == 'stop'
                                    if imgui.LoaderButton(is_stop_loading, fa('STOP') .. '  Закончить эфир', imgui.ImVec2(-1, 38)) then
                                        broadcast_action_state.name = ethers.vars.selected_ether
                                        broadcast_action_state.index = 'stop'
                                        ethersPlay(ether.lines[#ether.lines][3], ethers.vars, function()
                                            broadcast_action_state.name = nil
                                            broadcast_action_state.index = nil
                                        end)
                                    end
                                    imgui.Columns(1)
                                    imgui.Spacing()
                                    imgui.Separator()
                                    imgui.Spacing()
                                    
                                    for i = 2, #ether.lines - 1 do
                                        local action = ether.lines[i]
                                        local icon = action[1]
                                        local label = action[2]
                                        local lines = action[3]
                                        
                                        if label == 'Задать вопрос' then
                                            imgui.TextDisabled('ВОПРОСЫ ДЛЯ ИНТЕРВЬЮ')
                                            imgui.Spacing()
                                            for qi, question in ipairs(ethers.interv_questions) do
                                                if imgui.Selectable(question .. '##sq' .. qi) then
                                                    sampSendChat(u8:decode(question))
                                                end
                                            end
                                        else
                                            imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 5)
                                            local is_loading = broadcast_action_state.name == ethers.vars.selected_ether and broadcast_action_state.index == i
                                            if imgui.LoaderButton(is_loading, tostring(icon) .. "  " .. tostring(label) .. '##act' .. i, imgui.ImVec2(-1, 35)) then
                                                local allow = true
                                                if label == 'Первым был' or label == 'Назвать победителя' or label == 'Передать привет' then
                                                    local function check_val(val)
                                                        local num = tonumber(val)
                                                        if num then
                                                            if num < 0 then return false, "Недопустимый ID (" .. val .. ")" end
                                                            if not sampIsPlayerConnected(num) then return false, "Игрок под ID " .. val .. " не найден на сервере" end
                                                        else
                                                            if val == "" then return false, "Значение не может быть пустым" end
                                                        end
                                                        return true, nil
                                                    end
                                                    
                                                    local ok, err = check_val(ffi.string(ethers.vars.ID))
                                                    if not ok then
                                                        sampAddChatMessage(tag .. 'Ошибка в поле ID: ' .. err, -1)
                                                        allow = false
                                                    end
                                                    
                                                    if label == 'Передать привет' and allow then
                                                        local ok_to, err_to = check_val(ffi.string(ethers.vars.toID))
                                                        if not ok_to then
                                                            sampAddChatMessage(tag .. 'Ошибка в поле ID получателя: ' .. err_to, -1)
                                                            allow = false
                                                        end
                                                    end
                                                end
                                                
                                                if allow then
                                                    broadcast_action_state.name = ethers.vars.selected_ether
                                                    broadcast_action_state.index = i
                                                    ethersPlay(lines, ethers.vars, function()
                                                        broadcast_action_state.name = nil
                                                        broadcast_action_state.index = nil
                                                    end)
                                                end
                                            end
                                            imgui.PopStyleVar()
                                            imgui.Spacing()
                                        end
                                    end
                                else
                                    imgui.Columns(2, 'quick_btns', false)
                                    local is_start_loading = broadcast_action_state.name == ethers.vars.selected_ether and broadcast_action_state.index == 'start'
                                    if imgui.LoaderButton(is_start_loading, fa('PLAY') .. '  Начать эфир', imgui.ImVec2(-1, 40)) then
                                        broadcast_action_state.name = ethers.vars.selected_ether
                                        broadcast_action_state.index = 'start'
                                        ethersPlay(ether.lines[1][3], ethers.vars, function() 
                                            broadcast_action_state.name = nil 
                                            broadcast_action_state.index = nil 
                                        end)
                                    end
                                    imgui.NextColumn()
                                    local is_stop_loading = broadcast_action_state.name == ethers.vars.selected_ether and broadcast_action_state.index == 'stop'
                                    if imgui.LoaderButton(is_stop_loading, fa('STOP') .. '  Закончить эфир', imgui.ImVec2(-1, 40)) then
                                        broadcast_action_state.name = ethers.vars.selected_ether
                                        broadcast_action_state.index = 'stop'
                                        ethersPlay(ether.lines[#ether.lines][3], ethers.vars, function()
                                            broadcast_action_state.name = nil
                                            broadcast_action_state.index = nil
                                        end)
                                    end
                                    imgui.Columns(1)
                                    imgui.Spacing()
                                    imgui.Separator()
                                    imgui.Spacing()
                                    
                                    for i = 2, #ether.lines - 1 do
                                        local action = ether.lines[i]
                                        local icon = action[1]
                                        local label = action[2]
                                        local lines = action[3]
                                        
                                        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 5)
                                        local is_loading = broadcast_action_state.name == ethers.vars.selected_ether and broadcast_action_state.index == i
                                        if imgui.LoaderButton(is_loading, tostring(icon) .. "  " .. tostring(label) .. '##act' .. i, imgui.ImVec2(-1, 30)) then
                                            local allow = true
                                            if label == 'Первым был' or label == 'Назвать победителя' or label == 'Передать привет' then
                                                local function check_val(val)
                                                    local num = tonumber(val)
                                                    if num then
                                                        if num < 0 then return false, "Недопустимый ID (" .. val .. ")" end
                                                        if not sampIsPlayerConnected(num) then return false, "Игрок под ID " .. val .. " не найден на сервере" end
                                                    else
                                                        if val == "" then return false, "Значение не может быть пустым" end
                                                    end
                                                    return true, nil
                                                end
                                                
                                                local ok, err = check_val(ffi.string(ethers.vars.ID))
                                                if not ok then
                                                    sampAddChatMessage(tag .. 'Ошибка в поле ID: ' .. err, -1)
                                                    allow = false
                                                end
                                                
                                                if label == 'Передать привет' and allow then
                                                    local ok_to, err_to = check_val(ffi.string(ethers.vars.toID))
                                                    if not ok_to then
                                                        sampAddChatMessage(tag .. 'Ошибка в поле ID получателя: ' .. err_to, -1)
                                                        allow = false
                                                    end
                                                end
                                            end
                                            
                                            if allow then
                                                broadcast_action_state.name = ethers.vars.selected_ether
                                                broadcast_action_state.index = i
                                                ethersPlay(lines, ethers.vars, function()
                                                    broadcast_action_state.name = nil
                                                    broadcast_action_state.index = nil
                                                end)
                                            end
                                        end
                                        imgui.PopStyleVar()
                                        imgui.Spacing()
                                    end
                                end
                            imgui.EndChild()
                        end
                        if selected_key ~= 'sobes' then
                            imgui.Columns(1)
                        end
                    imgui.EndChild()
                    if font[18] then imgui.PopFont() end
                elseif current_tab == 5 then
                    if font[18] then imgui.PushFont(font[18]) end
                    imgui.TextCenter(fa('USER') .. ' СОБЕСЕДОВАНИЕ')
                    if font[18] then imgui.PopFont() end
                    imgui.SetCursorPosY(imgui.GetCursorPosY()+13)
                    imgui.Separator()
                    if font[16] then imgui.PushFont(font[16]) end
                    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.1, 0.1, 0.1, 0.3))
                    imgui.BeginChild('##ACTIONS', imgui.ImVec2(325, 375), true)
                        imgui.SetCursorPosY(imgui.GetCursorPosY()+5)
                        imgui.TextDisabled('ДЕЙСТВИЯ')
                        imgui.Separator()
                        imgui.Spacing()
                        
                        imgui.AlignTextToFramePadding()
                        imgui.Text(fa('user')..' ID игрока: ')
                        imgui.SameLine()
                        imgui.PushItemWidth(150)
                        imgui.InputInt('##INPUTID', sobes.id)
                        imgui.PopItemWidth()
                        imgui.Spacing()
                        
                        if imgui.Button(fa('handshake')..'  Приветствие', imgui.ImVec2(310,35)) then
                            if sobes.id[0] >= 0 and sobes.id[0] <= 1000 then
                                sampSendChat(u8:decode('Здравствуйте, '..sobes.nick..', Вы пришли на собеседование?'))
                                sobes.process = true
                            else
                                sampAddChatMessage(u8:decode(tag..'Вы не ввели ID игрока'), 0x008080)
                            end
                        end
                        imgui.Hint('hello', 'Автоматическая проверка документов')
                        imgui.Spacing()
                        if imgui.Button(fa('id_card')..'  Спросить документы', imgui.ImVec2(310,35)) then
                            lua_thread.create(function()
                                sampSendChat(u8:decode('Хорошо, тогда предоставьте мне пожалуйста ваш пакет документов, а именно:'))
                                wait(900)
                                sampSendChat(u8:decode('Паспорт, Медицинскую карту, а также ваши лицензии.'))
                                wait(900)
                                sampSendChat(u8:decode('/b Напишите в чат /showpass '..select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))))
                            end)
                        end
                        imgui.Spacing()
                        if imgui.Button(fa('question')..'  Вопрос 1', imgui.ImVec2(150,35)) then
                            sampSendChat(u8:decode('Расскажите о себе.'))
                        end
                        imgui.SameLine(170)
                        if imgui.Button(fa('question')..'  Вопрос 2', imgui.ImVec2(150,35)) then
                            sampSendChat(u8:decode('Почему вы выбрали именно наш радиоцентр?'))
                        end
                        imgui.Spacing()
                        imgui.Separator()
                        imgui.Spacing()
                        
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 0.6))
                        if imgui.Button(fa('CHECK')..'  Одобрить', imgui.ImVec2(310,35)) then
                            lua_thread.create(function()
                                sampSendChat(u8:decode('/todo Поздравляю, Вы прошли собеседование!*улыбаясь и протягивая человеку напротив ключи'))
                                wait(700)
                                sampSendChat(u8:decode('Раздевалка находится на первом этаже.'))
                                wait(700)
                                sampSendChat('/invite '..sobes.id[0])
                                sobes.process = false
                                sobes.id[0] = -1
                                sobes.nick = 'Неизвестно'
                                sobes.sex = 'Неизвестно'
                                sobes.zakon = 'Неизвестно'
                                sobes.lvl = 'Неизвестно'
                                sobes.org = 'Неизвестно'
                                sobes.narko = 'Неизвестно'
                                sobes.povestka = 'Неизвестно'
                            end)
                        end
                        imgui.PopStyleColor(1)
                        
                        imgui.Spacing()
                        
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6, 0.2, 0.2, 0.6))
                        if imgui.Button(fa('XMARK')..'  Отказать', imgui.ImVec2(310,35)) then
                            showRefusalPopup[0] = true
                        end
                        imgui.PopStyleColor(1)

                    imgui.EndChild()

                    imgui.SameLine()
                    if font[18] then imgui.PushFont(font[18]) end
                    imgui.BeginChild('##INFO', imgui.ImVec2(325, 375), true)
                        if sampIsPlayerConnected(sobes.id[0]) then
                            sobes.nick = sampGetPlayerNickname(sobes.id[0])
                        else
                            sobes.nick = 'Неизвестно'
                        end

                        imgui.TextCenter(sobes.nick .. '[' .. sobes.id[0] .. ']')
                        imgui.SetCursorPosY(imgui.GetCursorPosY()+3)
                        imgui.Separator()
                        imgui.Text('Пол: '..sobes.sex)
                        imgui.Text('Законопослушность: ' .. sobes.zakon)
                        imgui.Text('Уровень: ' .. sobes.lvl)
                        imgui.Text('Организация: ' .. sobes.org)
                        imgui.Text('Наркозависимость: ' .. sobes.narko)
                        imgui.Text('Повестка: '..sobes.povestka)
                        
                        imgui.Separator()

                        imgui.SetCursorPosY(imgui.GetCursorPosY()+100)
                        imgui.SetCursorPosX(imgui.GetCursorPosX()+20)

                        local status = '{AFAFAF}Неизвестно'
                        if type(sobes.lvl) ~= 'string' then
                            if sobes.lvl >= 3 and sobes.zakon >= 70 and sobes.org == 'Нет' and sobes.povestka == 'Нет' then
                                status = '{FFFF00}Годен'
                            else
                                status = '{FF0000}Не годен'
                            end
                        end

                        imgui.TextColoredRGB('Рекоммендация хелпера: '..status)
                        imgui.Hint('recommendation', ' Обратите внимание! Рекоммендация хелпера - вспомогательный\nинструмент и не является окончательным решением.\nРекоммендация формируется из уровня, организации, медкарты,\nзаконопослушности и наличия повестки.')
                        
                        if font[18] then imgui.PopFont() end
                    imgui.EndChild()
                    if font[16] then imgui.PopFont() end
                    imgui.PopStyleColor()
                elseif current_tab == 6 then
                    if font[18] then imgui.PushFont(font[18]) end
                    imgui.TextCenter(fa('GRADUATION_CAP') .. " ЭКЗАМЕНЫ")
                    imgui.Separator()
                    imgui.Spacing()
                    
                    imgui.BeginChild('ExamTabs', imgui.ImVec2(0, 40), false)
                        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(40, 0))
                        imgui.SetCursorPosX(220)
                        if imgui.HeaderButton(exam_selected_tab == 1, 'ПРО') then exam_selected_tab = 1 end
                        imgui.SameLine()
                        if imgui.HeaderButton(exam_selected_tab == 2, 'ППЭ') then exam_selected_tab = 2 end
                        imgui.SameLine()
                        if imgui.HeaderButton(exam_selected_tab == 3, 'Устав') then exam_selected_tab = 3 end
                        imgui.PopStyleVar()
                    imgui.EndChild()
                    imgui.Spacing()
                    
                    imgui.BeginChild('ExamContent', imgui.ImVec2(0, 0), false)
                        if exam_selected_tab == 1 then
                            if imgui.Button('Приветствие', imgui.ImVec2(660, 35)) then
                                sampSendChat(u8:decode('Приветствую, вы готовы сдать ПРО?'))
                            end
                            imgui.Hint('pro_0', 'В чат: Приветствую, вы готовы сдать ПРО?')

                            imgui.Spacing()
                            imgui.Separator()
                            imgui.Spacing()
                            
                            if imgui.Button('Вопрос #1', imgui.ImVec2(326, 35)) then
                                sampSendChat(u8:decode('Назови мне сокращение для автомобилей.'))
                            end
                            imgui.Hint('pro_1', 'В чат: Назови мне сокращение для автомобилей.')

                            imgui.SameLine()
                            
                            if imgui.Button('Вопрос #6', imgui.ImVec2(326, 35)) then
                                sampSendChat(u8:decode('Назови мне сокращение для тюнинга.'))
                            end
                            imgui.Hint('pro_6', 'В чат: Назови мне сокращение для тюнинга.')    
                            
                            if imgui.Button('Вопрос #2', imgui.ImVec2(326, 35)) then
                                sampSendChat(u8:decode('Назови мне сокращение для аксессуаров.'))
                            end
                            imgui.Hint('pro_2', 'В чат: Назови мне сокращение для аксессуаров.')
                            
                            imgui.SameLine()
                            
                            if imgui.Button('Вопрос #7', imgui.ImVec2(326, 35)) then
                                sampSendChat(u8:decode('Назови мне сокращение для бизнесов.'))
                            end
                            imgui.Hint('pro_7', 'В чат: Назови мне сокращение для бизнесов.')
                            
                            if imgui.Button('Вопрос #3', imgui.ImVec2(326, 35)) then
                                sampSendChat(u8:decode('Назови мне сокращение для бизнесов.'))
                            end
                            imgui.Hint('pro_3', 'В чат: Назови мне сокращение для бизнесов.')

                            imgui.SameLine()

                            if imgui.Button('Вопрос #8', imgui.ImVec2(326, 35)) then
                                sampSendChat(u8:decode('Назови мне сокращение для аксессуаров.'))
                            end
                            imgui.Hint('pro_8', 'В чат: Назови мне сокращение для аксессуаров.')
                            
                            if imgui.Button('Вопрос #4', imgui.ImVec2(326, 35)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('Допустим, пришло такое объявление:'))
                                    wait(1000)
                                    sampSendChat(u8:decode('"Продам БМВ Е7"'))
                                    wait(1000)
                                    sampSendChat(u8:decode('Как ты его отредактируешь?'))
                                end)
                            end
                            imgui.Hint('pro_4', 'В чат: Допустим, пришло такое объявление...')

                            imgui.SameLine()

                            if imgui.Button('Вопрос #9', imgui.ImVec2(326, 35)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('Допустим, пришло такое объявление:'))
                                    wait(1000)
                                    sampSendChat(u8:decode('"Продам БМВ Е7"'))
                                    wait(1000)
                                    sampSendChat(u8:decode('Как ты его отредактируешь?'))
                                end)
                            end
                            imgui.Hint('pro_9', 'В чат: Допустим, пришло такое объявление...')
                            
                            if imgui.Button('Вопрос #5', imgui.ImVec2(326, 35)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('Допустим, пришло такое объявление:'))
                                    wait(1000)
                                    sampSendChat(u8:decode('"Куплю чай по 5к штука"'))
                                    wait(1000)
                                    sampSendChat(u8:decode('Как ты его отредактируешь?'))
                                end)
                            end
                            imgui.Hint('pro_5', 'В чат: Допустим, пришло такое объявление...')

                            imgui.SameLine()

                            if imgui.Button('Вопрос #10', imgui.ImVec2(326, 35)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('Допустим, пришло такое объявление:'))
                                    wait(1000)
                                    sampSendChat(u8:decode('"куплю фт спорт+ за 230кк"'))
                                    wait(1000)
                                    sampSendChat(u8:decode('Как ты его отредактируешь?'))
                                end)
                            end
                            imgui.Hint('pro_10', 'В чат: Допустим, пришло такое объявление...')

                            imgui.Spacing()
                            imgui.Separator()
                            imgui.Spacing()

                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 0.6))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.7, 0.3, 0.7))
                            if imgui.Button('Сдал', imgui.ImVec2(326, 32)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('Поздравляю, вы сдали ПРО!'))
                                    wait(100)
                                    sampSendChat('/time')
                                end)
                            end
                            imgui.PopStyleColor(2)
                            imgui.Hint('pro_pass', 'В чат: Поздравляю, вы сдали ПРО!')

                            imgui.SameLine()
                            
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6, 0.2, 0.2, 0.6))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.7, 0.3, 0.3, 0.7))
                            if imgui.Button('Не сдал', imgui.ImVec2(326, 32)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('К сожалению, вы не сдали ПРО.'))
                                    wait(1000)
                                    sampSendChat(u8:decode('Не расстраивайтесь, подучите и приходите позже!'))
                                end)
                            end
                            imgui.PopStyleColor(2)
                            imgui.Hint('pro_fail', 'В чат: К сожалению, вы не сдали ПРО...')
                        elseif exam_selected_tab == 2 then
                            if imgui.Button('Приветствие', imgui.ImVec2(660, 35)) then
                                sampSendChat(u8:decode('Приветствую, вы готовы сдать ППЭ?'))
                            end
                            imgui.Hint('ppe_1', 'В чат: Приветствую, вы готовы сдать ППЭ?')
                            imgui.Spacing()
                            imgui.Separator()
                            imgui.Spacing()
                            if imgui.Button('Вопрос #1', imgui.ImVec2(660, 35)) then
                                sampSendChat(u8:decode('Подскажи, что нужно сделать перед тем, как начать эфир?'))
                            end
                            imgui.Hint('ppe_2', 'В чат: Подскажи, что нужно сделать перед тем, как начать эфир?')
                            if imgui.Button('Вопрос #2', imgui.ImVec2(660, 35)) then
                                sampSendChat(u8:decode('Назови мне тэг нашей радиостанции в рации департамента'))
                            end
                            imgui.Hint('ppe_3', 'В чат: Назови мне тэг нашей радиостанции в рации департамента')
                            if imgui.Button('Вопрос #3', imgui.ImVec2(660, 35)) then
                                sampSendChat(u8:decode('Можно ли материться в эфирах?'))
                            end
                            imgui.Hint('ppe_4', 'В чат: Можно ли материться в эфирах?')
                            if imgui.Button('Вопрос #4', imgui.ImVec2(660, 35)) then
                                sampSendChat(u8:decode('Можно ли оскорблять кого-либо в эфирах?'))
                            end
                            imgui.Hint('ppe_5', 'В чат: Можно ли оскорблять кого-либо в эфирах?')
                            if imgui.Button('Вопрос #5', imgui.ImVec2(660, 35)) then
                                sampSendChat(u8:decode('Можно ли проводить эфир без забития?'))
                            end
                            imgui.Hint('ppe_6', 'В чат: Можно ли проводить эфир без забития?')
                            imgui.Spacing()
                            imgui.Separator()
                            imgui.Spacing()
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.6, 0.2, 0.6))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.3, 0.7, 0.3, 0.7))
                            if imgui.Button('Сдал', imgui.ImVec2(326, 35)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('Поздравляю, вы сдали ППЭ!'))
                                    wait(100)
                                    sampSendChat('/time')
                                end)
                            end
                            imgui.PopStyleColor(2)
                            imgui.Hint('ppe_pass', 'В чат: Поздравляю, вы сдали ППЭ!')
                            imgui.SameLine()
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6, 0.2, 0.2, 0.6))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.7, 0.3, 0.3, 0.7))
                            if imgui.Button('Не сдал', imgui.ImVec2(326, 35)) then
                                lua_thread.create(function()
                                    sampSendChat(u8:decode('К сожалению, вы не сдали ППЭ.'))
                                    wait(1000)
                                    sampSendChat(u8:decode('Не расстраивайтесь, подучите и приходите позже!'))
                                end)
                            end
                            imgui.PopStyleColor(2)
                            imgui.Hint('ppe_fail', 'В чат: К сожалению, вы не сдали ППЭ...')
                        elseif exam_selected_tab == 3 then
                            imgui.TextDisabled('В разработке...')
                        end
                    imgui.EndChild()
                    if font[18] then imgui.PopFont() end
                elseif current_tab == 7 then
                    if font[18] then imgui.PushFont(font[18]) end
                    imgui.TextCenter(fa('GEAR') .. " НАСТРОЙКИ СКРИПТА")
                    imgui.Separator()
                    imgui.Spacing()
                    
                    imgui.BeginChild('SettingsMain', imgui.ImVec2(0, 0), false)
                        imgui.Columns(2, 'settings_cols', false)
                        imgui.SetColumnWidth(0, 300)
                        
                        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.1, 0.1, 0.1, 0.3))
                        imgui.BeginChild('GeneralSettings', imgui.ImVec2(290, -1), true)
                            imgui.TextDisabled('ОСНОВНОЕ')
                            imgui.Separator()
                            imgui.Spacing()
                            local auto_send = imgui.new.bool(cfg.settings.auto_send)
                            if imgui.ToggleButton('Авто-отправка объявлений', auto_send) then
                                cfg.settings.auto_send = auto_send[0]
                                save_config()
                            end
                            imgui.Hint('autosend', 'Если включено, то при нахождении объявления в базе,\nскрипт автоматически будет отправлять его.')
                            local auto_helper = imgui.new.bool(cfg.settings.auto_open_helper)
                            if imgui.ToggleButton('Автооткрытие помощника объявлений', auto_helper) then
                                cfg.settings.auto_open_helper = auto_helper[0]
                                save_config()
                            end
                            imgui.Hint('autoopen', 'Если включено, то вам не нужно будет открывать\nвручную помощник объявлений. Он будет открываться сам')
                            
                            local suggestions_enabled = imgui.new.bool(cfg.settings.suggestions_enabled)
                            if imgui.ToggleButton('Окно предложений', suggestions_enabled) then
                                cfg.settings.suggestions_enabled = suggestions_enabled[0]
                                save_config()
                            end
                            imgui.Hint('suggestions', 'Если включено, то при обнаружении похожего объявления\nно не точного, будет открываться окно с предложением.')
                            imgui.Spacing()
                            imgui.Separator()
                            imgui.Spacing()
                            imgui.TextDisabled('ГОРЯЧИЕ КЛАВИШИ')
                            imgui.Spacing()
                            HotkeyButton("Открыть меню", "menu")
                            HotkeyButton("Поймать объявление", "catchAd")
                            HotkeyButton("Скопировать объявление", "copyAd")
                            HotkeyButton("Помощь ПРО", "helper")
                        imgui.EndChild()
                        imgui.PopStyleColor()
                        
                        imgui.NextColumn()
                        
                        imgui.BeginChild('RightSettings', imgui.ImVec2(0, -1), false)
                            imgui.BeginChild('EtherConfig', imgui.ImVec2(0, 230), false)
                                if font[16] then imgui.PushFont(font[16]) end
                                imgui.TextDisabled('ДАННЫЕ ДЛЯ ЭФИРОВ')
                                imgui.Separator()
                                imgui.Spacing()
                                
                                imgui.PushItemWidth(-1)
                                local function ConfigInput(label, buf)
                                    imgui.Text(label)
                                    if imgui.InputText('##cfg_' .. label, buf, 256) then ethersSave() end
                                    imgui.Spacing()
                                end
                                
                                ConfigInput('Ваш ник (Имя Фамилия)', ethers.buffers.name)
                                ConfigInput('Ваша должность в СМИ', ethers.buffers.duty)
                                ConfigInput('Тег организации в /d', ethers.buffers.tagCNN)
                                ConfigInput('Ваш город', ethers.buffers.city)
                                ConfigInput('Название сервера', ethers.buffers.server)
                                ConfigInput('Музыкальная заставка', ethers.buffers.music)
                                
                                imgui.Text('Задержка между строк')
                                if imgui.SliderInt('##cfg_delay', ethers.buffers.delay, 1, 10, '%d сек') then ethersSave() end
                                imgui.Hint('delay', 'Выберите время которое скрипт должен подождать перед отправкой следующей строки в эфире.')
                                imgui.PopItemWidth()
                                if font[16] then imgui.PopFont() end
                            imgui.EndChild()
                            
                            imgui.Spacing()
                            imgui.Separator()
                            imgui.Spacing()
                            
                            imgui.BeginChild('ThemeConfig', imgui.ImVec2(0, 0), true)
                                imgui.TextDisabled('ТЕМА И ВНЕШНИЙ ВИД')
                                imgui.Spacing()
                                
                                local acc = cfg.theme.Accent or {0.28, 0.38, 0.58, 1.0}
                                local color_buf = imgui.new.float[4](acc[1], acc[2], acc[3], acc[4])
                                
                                imgui.PushItemWidth(200)
                                if imgui.ColorEdit4('Основной цвет##accent', color_buf, imgui.ColorEditFlags.AlphaBar) then
                                    updateThemeFromAccent({color_buf[0], color_buf[1], color_buf[2], color_buf[3]})
                                end
                                imgui.PopItemWidth()
                                
                                imgui.Spacing()
                                if imgui.Button('Сбросить тему', imgui.ImVec2(-1, 30)) then
                                    resetTheme()
                                end
                            imgui.EndChild()
                        imgui.EndChild()

                        imgui.Columns(1)
                    imgui.EndChild()
                    if font[18] then imgui.PopFont() end
                end
                imgui.PopStyleVar()
            imgui.EndChild()
            imgui.PopStyleColor(2)
        imgui.EndGroup()
        imgui.End()
        imgui.PopStyleVar()

        if edit_modal.state[0] then imgui.OpenPopup('Редактирование') end
        imgui.SetNextWindowPos(imgui.ImVec2(imgui.GetIO().DisplaySize.x * 0.5, imgui.GetIO().DisplaySize.y * 0.5), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(530, 170), imgui.Cond.Always)
        
        if imgui.BeginPopup('Редактирование', imgui.WindowFlags.NoResize) then
            if font[18] then imgui.PushFont(font[18]) end
            imgui.TextCenter('Редактирование объявления #'..edit_modal.index)
            if font[18] then imgui.PopFont() end
            imgui.Separator()
            if font[16] then imgui.PushFont(font[16]) end
            imgui.PushItemWidth(515)
            imgui.Text("Оригинал: ")
            imgui.InputText('##Orig', edit_modal.original, 256)
            imgui.Text("Редакция: ")
            imgui.SameLine()
            if string.len(u8:decode(ffi.string(edit_modal.edited))) < 80 then
                imgui.TextColoredRGB("{FFFFFF}({00FF00}"..string.len(u8:decode(ffi.string(edit_modal.edited))).."{FFFFFF}/80 символов)")
            else
                imgui.TextColoredRGB("{FFFFFF}({FF0000}"..string.len(u8:decode(ffi.string(edit_modal.edited))).."{FFFFFF}/80 символов)")
            end
            imgui.InputText('##Edit', edit_modal.edited, 256)
            imgui.Spacing()
            if imgui.Button('Сохранить', imgui.ImVec2(255, 30)) then
                if edit_modal.index > 0 and ads[edit_modal.index] then
                    if string.len(u8:decode(ffi.string(edit_modal.edited))) > 80 then
                        sampAddChatMessage(u8:decode(tag..'Не более 80 символов!'), 0x008080)
                    else
                        ads[edit_modal.index].my_text = ffi.string(edit_modal.edited)
                        save_ads()
                        update_search()
                        edit_modal.state[0] = false
                        imgui.CloseCurrentPopup()
                    end
                end
            end
            imgui.SameLine()
            if imgui.Button('Отмена', imgui.ImVec2(255, 30)) then edit_modal.state[0] = false; imgui.CloseCurrentPopup() end
            imgui.PopItemWidth()
            if font[16] then imgui.PopFont() end
            imgui.EndPopup()
        end

        if showRefusalPopup[0] then imgui.OpenPopup('RefusalMenu') end
        if imgui.BeginPopupModal('RefusalMenu', showRefusalPopup, imgui.WindowFlags.AlwaysAutoResize) then
            imgui.Text("Выберите причину отказа:")
            imgui.Separator()
            local reasons = {
                "Проф. непригоден",
                "Низкая законопослушность",
                "Опечатка в паспорте",
                "Психически нездоров",
                "Бред",
                "Нет лицензий",
                "Наркозависимость"
            }
            for _, reason in ipairs(reasons) do
                if imgui.Button(reason, imgui.ImVec2(250, 30)) then
                    lua_thread.create(function() 
                        sampSendChat(u8:decode('/todo Вы нам не подходите. Причина: ' .. reason .. '*возращая документы гражданину'))
                    end)
                    showRefusalPopup[0] = false
                    sobes.process = false
                end
            end
            imgui.Separator()
            if imgui.Button('Закрыть', imgui.ImVec2(250, 25)) then showRefusalPopup[0] = false end
            imgui.EndPopup()
        end
        imgui.SetMouseCursor(-1)
    end
)

function appendDialogText(text)
    local code = string.format("(() => {var d = document.querySelector('.dialog');if (!d) return;var i = d.querySelector('input.dialog-input__field');if (!i) return;i.value = i.value + %q;})()", tostring(text))
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
    pcall(function()
        local current = orig_sampGetCurrentDialogEditboxText() or ""
        
        local m_pEditbox = memory.getuint32(sampGetDialogInfoPtr() + 0x24, true)
        if m_pEditbox ~= 0 then
            orig_sampSetCurrentDialogEditboxText(current .. text)
        end
    end)
end

local helper_window = imgui.OnFrame(
    function() return win.helper[0] end,
	function(player)
        if anims.helper_target then
            if anims.helper_alpha < 1.0 then
                anims.helper_alpha = anims.helper_alpha + (1.0 - anims.helper_alpha) * 0.12
                if anims.helper_alpha > 0.995 then anims.helper_alpha = 1.0 end
            end
        else
            if anims.helper_alpha > 0.0 then
                anims.helper_alpha = anims.helper_alpha - (0.01 + anims.helper_alpha) * 0.15
                if anims.helper_alpha < 0.01 then 
                    anims.helper_alpha = 0
                    win.helper[0] = false
                end
            end
        end
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, anims.helper_alpha)
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 1.05, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(1, 0.5))
		imgui.SetNextWindowSizeConstraints(imgui.ImVec2(400, 500), imgui.ImVec2(400, 800))
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(10, 10))
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 10)
		imgui.Begin('Help Window ##helper', win.helper, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
 			if font[16] then imgui.PushFont(font[16]) end
            imgui.TextCenter(fa('LIGHTBULB') .. " ПОМОЩЬ ПРО")
            imgui.Separator()
            imgui.Spacing()

			for i=1, #help_tabs_info.first do
				if imgui.CollapsingHeader(help_tabs_info.first[i][1]..'##i'..i) then
					local tSize, btn_count = 0, 0
					local wSize = 380
					for f=2, #help_tabs_info.first[i] do
                        local btn_text = help_tabs_info.first[i][f][1]
						local TextSize = imgui.CalcTextSize(btn_text).x + 20
						if tSize + TextSize + 10 < wSize and btn_count < 7 then
							if btn_count > 0 then imgui.SameLine() end
						else
                            tSize, btn_count = 0, 0
                        end
                        tSize = tSize + TextSize + 10
                        btn_count = btn_count + 1

						if imgui.Button(btn_text..'##if'..i..f, imgui.ImVec2(TextSize, 25)) then
                            local insert_text = help_tabs_info.first[i][f][2]
                            local decoded_text = u8:decode(insert_text)
							if decoded_text:find('*', 1, true) then
								sampSetCurrentDialogEditboxText(decoded_text:gsub('%%%*', ''))
                                setDialogCursorPos(decoded_text:find('*', 1, true) - 1)
							elseif decoded_text:find('""', 1, true) then
								sampSetCurrentDialogEditboxText(decoded_text)
                                setDialogCursorPos(decoded_text:find('""', 1, true))
							else
								sampSetCurrentDialogEditboxText(decoded_text)
							end 
						end
						imgui.Hint('help_hint'..i..f, 'Вставит в диалог: ' .. help_tabs_info.first[i][f][2])
					end
				end
			end
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            imgui.TextCenter('Сокращения')
            imgui.NewLine()
            local tSize_s, btn_count_s = 0, 0
            for i=1, #help_tabs_info.second do
				local wSize = 380
				for f=2, #help_tabs_info.second[i] do
                    local btn_text = help_tabs_info.second[i][f]
					local TextSize = imgui.CalcTextSize(btn_text).x + 20
                    
					if tSize_s + TextSize + 10 < wSize and btn_count_s < 7 then
                        if btn_count_s > 0 then imgui.SameLine() end
					else
                        tSize_s, btn_count_s = 0, 0
                    end
                    tSize_s = tSize_s + TextSize + 10
                    btn_count_s = btn_count_s + 1
                    
                    if imgui.Button(btn_text..'##is'..i, imgui.ImVec2(TextSize, 25)) then
                        local insert_text = help_tabs_info.second[i][2]
                        local decoded_text = u8:decode(insert_text)
                        appendDialogText(decoded_text)
                    end
                    imgui.Hint('help_hint'..i, 'Вставит в диалог: ' .. help_tabs_info.second[i][2])
                end
            end
            if imgui.Button('Закрыть', imgui.ImVec2(-1, 35)) then anims.helper_target = false end
            if font[16] then imgui.PopFont() end
        imgui.End()
        imgui.PopStyleVar()

        imgui.PopStyleVar()
        imgui.PopStyleVar()
        imgui.SetMouseCursor(-1)
	end
)

imgui.OnFrame(function() return suggestion.window[0] end, function(player)
    if anims.sugg_target then
        if anims.sugg_alpha < 1.0 then
            anims.sugg_alpha = anims.sugg_alpha + (1.0 - anims.sugg_alpha) * 0.12
            if anims.sugg_alpha > 0.995 then anims.sugg_alpha = 1.0 end
        end
    else
        if anims.sugg_alpha > 0.0 then
            anims.sugg_alpha = anims.sugg_alpha - (0.01 + anims.sugg_alpha) * 0.15
            if anims.sugg_alpha < 0.01 then 
                anims.sugg_alpha = 0
                suggestion.window[0] = false
            end
        end
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, anims.sugg_alpha)
    local resX, resY = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2 + 300), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(550, 200), imgui.Cond.FirstUseEver)
    
    imgui.Begin("Предложение на основе содержимого", suggestion.window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
    player.HideCursor = true
    if font[18] then imgui.PushFont(font[18]) end
    imgui.TextCenter(fa('LIGHTBULB') .. " Предложение на основе содержимого")
    if font[18] then imgui.PopFont() end

    if font[16] then imgui.PushFont(font[16]) end
    imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1.0), "Текст оригинального объявления:")
    imgui.PushTextWrapPos(imgui.GetWindowWidth() - 10)
    imgui.Text(suggestion.original_text)
    imgui.PopTextWrapPos()
    
    imgui.Separator()
    
    if #suggestion.matches > 0 then
        local current_match = suggestion.matches[suggestion.current_idx].item.my_text
        imgui.Text("Вариант " .. tostring(suggestion.current_idx) .. " из " .. tostring(#suggestion.matches) .. ":")
        imgui.PushTextWrapPos(imgui.GetWindowWidth() - 10)
        imgui.TextColored(imgui.ImVec4(0.2, 0.8, 0.2, 1.0), current_match)
        imgui.PopTextWrapPos()
        
        imgui.Separator()
        imgui.Spacing()

        imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 98)
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 5)
        
        if imgui.Button("<##prev_sugg", imgui.ImVec2(30, 25)) and suggestion.current_idx > 1 then
            suggestion.current_idx = suggestion.current_idx - 1
            if sampIsDialogActive() then
                sampSetCurrentDialogEditboxText(u8:decode(suggestion.matches[suggestion.current_idx].item.my_text))
            end
        end
        
        imgui.SameLine()
        
        if imgui.Button("Применить", imgui.ImVec2(120, 25)) then
            if sampIsDialogActive() then
                sampSetCurrentDialogEditboxText(u8:decode(suggestion.matches[suggestion.current_idx].item.my_text))
            end
            anims.sugg_target = false
        end
        
        imgui.SameLine()

        if imgui.Button(">##next_sugg", imgui.ImVec2(30, 25)) and suggestion.current_idx < #suggestion.matches then
            suggestion.current_idx = suggestion.current_idx + 1
            if sampIsDialogActive() then
                sampSetCurrentDialogEditboxText(u8:decode(suggestion.matches[suggestion.current_idx].item.my_text))
            end
        end

        imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 50)

        if imgui.Button("Закрыть", imgui.ImVec2(100, 25)) then
            anims.sugg_target = false
        end

        imgui.PopStyleVar()
    end
    if font[16] then imgui.PopFont() end
    imgui.End()
    imgui.PopStyleVar()
end)

function ev.onShowDialog(id, style, title, button1, button2, text)
    local encodedTitle = u8:encode(title)
    
	if encodedTitle == '{BFBBBA}Редактирование' then
		local ad = u8:encode(text):match('Сообщение:%s*[\r\n]*{%x+}([^\r\n]*)')
		if ad then
			ad = ad:gsub('%s*\n', ''):gsub('\\', '/')
            
			local saved = nil
			local input_cp1251 = u8:decode(ad)
			local input_lower = lower_cp1251(input_cp1251)
			local input_norm = input_lower:gsub("%s+", " "):match("^%s*(.-)%s*$") or input_lower

            local input_words = {}
            for word in input_norm:gmatch("%S+") do
                table.insert(input_words, word)
            end
            local potential_matches = {}

			for _, ah in ipairs(ads) do
				if ah.my_text ~= '' then
					local item_cp1251 = u8:decode(ah.text)
					local item_lower = lower_cp1251(item_cp1251)
					local item_norm = item_lower:gsub("%s+", " "):match("^%s*(.-)%s*$") or item_lower

					if item_norm == input_norm then
						saved = ah.my_text
						break
					end
                    
                    local matches = 0
                    for _, word in ipairs(input_words) do
                        if item_norm:find(word, 1, true) then matches = matches + 1 end
                    end
                    
                    local threshold = math.ceil(#input_words * 0.60)
                    if threshold == 0 then threshold = 1 end

                    if matches >= threshold then
                        local len_diff = math.abs(#item_norm - #input_norm)
                        table.insert(potential_matches, {
                            item = ah,
                            matches = matches,
                            len_diff = len_diff
                        })
                    end
				end
			end

            if saved and cfg.settings.auto_send then
                local res_text = u8:decode(saved)
                if #res_text > 80 then
                    sampAddChatMessage(u8:decode(tag .. 'Авто-отправка отменена: текст слишком длинный ('..#res_text..'/80)'), 0x008080)
                else
                    local today = os.date("%Y-%m-%d")
                    if not stats[today] then stats[today] = {ads = 0, money = 0} end
                    stats[today].ads = stats[today].ads + 1
                    save_stats()
                    
                    sampSendDialogResponse(id, 1, -1, res_text)
                    return false
                end
            end
            
			currentAd = { original = ad, id = id, style = style, title = title, button1 = button1, button2 = button2, text = text..'                                                                                                                               .' }
			currentAd.savedText = saved
            
            if not saved and #potential_matches > 0 and cfg.settings.suggestions_enabled then
                table.sort(potential_matches, function(a, b)
                    if a.matches == b.matches then return a.len_diff < b.len_diff end
                    return a.matches > b.matches
                end)
                suggestion.matches = potential_matches
                suggestion.current_idx = 1
                suggestion.original_text = ad
                if not suggestion.window[0] then anims.sugg_alpha = 0 end
                suggestion.window[0] = true
                anims.sugg_target = true
            else
                anims.sugg_target = false
            end

			lua_thread.create(function(adId, savedTxt)
                local last_text = ''
				wait(10)
				if savedTxt then
                    sampSetCurrentDialogEditboxText(u8:decode(savedTxt))
				else
                    if suggestion.window[0] then
                        sampSetCurrentDialogEditboxText(u8:decode(suggestion.matches[1].item.my_text))
                    else
					    sampSetCurrentDialogEditboxText('')
                        if cfg.settings.auto_open_helper then
                            win.helper[0] = true
                            anims.helper_target = true
                            anims.helper_alpha = 0
                        end
                    end
				end

				local function isComboPressed(keys)
                    if not keys or #keys == 0 then return false end
                    for _, k in ipairs(keys) do if not isKeyDown(k) then return false end end
                    for _, k in ipairs(keys) do if wasKeyPressed(k) then return true end end
                    return false
                end

				while sampIsDialogActive() and sampGetDialogCaption() and u8:encode(sampGetDialogCaption()) == '{BFBBBA}Редактирование' do
					wait(0)
                    local copyAdKeys = cfg.binds.copyAd
					if copyAdKeys and #copyAdKeys > 0 and isComboPressed(copyAdKeys) then
						if u8:encode(sampGetDialogText()):find('Сообщение:%s+{33AA33}(.-)%s*[\r\n]') then
							local textdown = u8:encode(sampGetDialogText()):match('Сообщение:%s+{33AA33}(.-)%s*[\r\n]')
							sampSetCurrentDialogEditboxText(u8:decode(textdown))
						end
					end

					local editbox_text = sampGetCurrentDialogEditboxText()
					local text = editbox_text and u8:encode(editbox_text) or ""

                    if text ~= last_text then
                        last_text = text
					    for i=2, #autoBind do
                            if type(autoBind[i]) == 'table' and autoBind[i][1] and autoBind[i][2] then
						        local au = (autoBind[1][1] .. autoBind[i][1]):gsub('([%%%^%$%(%)%.%[%]%*%+%-%?])', '%%%1')
						        if text:find(au) then
                                    local gCur = getDialogCursorPos()
							        sampSetCurrentDialogEditboxText(u8:decode(tostring(text:gsub(au, autoBind[i][2]))))
                                    setDialogCursorPos(gCur - #autoBind[i][1] + #u8:decode(autoBind[i][2]))
							        text = u8:encode(sampGetCurrentDialogEditboxText())
                                    last_text = text
						        end
                            end
					    end
                    end

					for _, btn in ipairs(keyBind) do
						if type(btn) == 'table' and btn[1] and type(btn[1]) == 'table' and ((#btn[1] == 1 and wasKeyPressed(btn[1][1])) or (#btn[1] == 2 and isKeyDown(btn[1][1]) and wasKeyPressed(btn[1][2]))) then
							local cur_text = u8:encode(sampGetCurrentDialogEditboxText())
                            sampSetCurrentDialogEditboxText(u8:decode(cur_text .. (btn[2] or "")))
						end
					end
				end

			end, currentAd.id, currentAd.savedText)
		else
			currentAd = nil
		end
		
		text = text..'                                                                                                                                .'
		return {id, style, title, button1, button2, text}
	end
end
function ev.onSendDialogResponse(id, button, list, input)
	if button == 1 and currentAd and input ~= '' then
        if #input > 80 then
            sampAddChatMessage(u8:decode(tag .. 'Ошибка: Слишком длинный текст ('..#input..'/80). Сократите объявление!'), 0x008080)
            local backupAd = currentAd
            lua_thread.create(function()
                local current_input = input
                while true do
                    wait(10)
                    sampShowDialog(backupAd.id, backupAd.title, backupAd.text, backupAd.button1, backupAd.button2, backupAd.style)
                    sampSetCurrentDialogEditboxText(current_input)
                    currentAd = backupAd
                    
                    local reshow = false
                    while sampIsDialogActive() do
                        local result, btn, list, out_input = sampHasDialogRespond(backupAd.id)
                        if result then
                            if btn == 1 then
                                if #out_input > 80 then
                                    sampAddChatMessage(u8:decode(tag .. 'Ошибка: Слишком длинный текст ('..#out_input..'/80). Сократите объявление!'), 0x008080)
                                    current_input = out_input
                                    reshow = true
                                    break
                                else
                                    currentAd = backupAd
                                    sampSendDialogResponse(backupAd.id, 1, list, out_input)
                                    return
                                end
                            else
                                currentAd = nil
                                sampSendDialogResponse(backupAd.id, 0, list, out_input)
                                return
                            end
                        end
                        wait(0)
                    end
                    if not reshow then return end
                end
            end)
            return false
        end

		local saved_text = u8:encode(input):gsub('%s+', ' '):gsub('\\', '/')

		if saved_text:match('^%[%d+%] %w+_%w+$') or saved_text:match('%w+_%w+%[%d+%]%s*$') or saved_text:match('^%w+_%w+$') then
			currentAd = nil
			return
		end

		local found = false
		for i, v in ipairs(ads) do
			if v.text == currentAd.original then
				ads[i].my_text = saved_text
				found = true
				break
			end
		end

		if not found then
			table.insert(ads, { text = currentAd.original, my_text = saved_text })
		end

		save_ads()
        
        local today = os.date("%Y-%m-%d")
        if not stats[today] then stats[today] = {ads = 0, money = 0} end
        stats[today].ads = stats[today].ads + 1
        save_stats()
        
        update_search()
        if win.helper[0] then anims.helper_target = false end
        anims.sugg_target = false
	end
	currentAd = nil
    anims.sugg_target = false
end
function ev.onServerMessage(color, text)
    local clean_text = u8:encode(text):gsub('{%x%x%x%x%x%x}', '')

    -- [Информация] {ffffff}Вы получили $440.000 за отредактированое вами объявление.
    local raw_money_ad = clean_text:match('Вы получили%s+(.+)%s+за отредактированое вами объявление')
    if raw_money_ad then
        local money = raw_money_ad:gsub('%D', '')
        if money then
            local today = os.date("%Y-%m-%d")
            if not stats[today] then stats[today] = {ads = 0, money = 0} end
            stats[today].money = (stats[today].money or 0) + money
            save_stats()
        end
    end

    -- [Информация] {ffffff}Так же Вы получаете доплату за ранг $352.000.
    local raw_money_rank = clean_text:match('Так же Вы получаете доплату за ранг%s+(.+)')
    if raw_money_rank then
        local money = raw_money_rank:gsub('%D', '')
        if money then
            local today = os.date("%Y-%m-%d")
            if not stats[today] then stats[today] = {ads = 0, money = 0} end
            stats[today].money = (stats[today].money or 0) + money
            save_stats()
        end
    end
    --print(color .. ': clr, text: '..text)
end

function onReceivePacket(id, bs)
    if id == 220 then
        raknetBitStreamIgnoreBits(bs, 8)
        if raknetBitStreamReadInt8(bs) == 17 then
            raknetBitStreamIgnoreBits(bs, 32)
            local length = raknetBitStreamReadInt16(bs)
            local encoded = raknetBitStreamReadInt8(bs)
            local str = (encoded ~= 0) and raknetBitStreamDecodeString(bs, length + encoded) or raknetBitStreamReadString(bs, length)
            if sobes.process and str:find("event.documents.inititalizeData") then
                local event, js = str:match("window%.executeEvent%(%'(.+)%'%, %`(.+)%`%)%;")
                local data = decodeJson(js)
                data = data[1]
                if data.type == 1 then
                    sobes.lvl = tonumber(data.level:match("%d+"))
                    sobes.zakon = tonumber(string.match(data.zakono, "^(%d+)/"))

                    sobes.povestka = u8(data.agenda)

                    sobes.sex = u8(data.sex)

                    if data.charity == 'Нет' then
                        sobes.org = 'Нет'
                    else
                        sobes.org = u8(data.charity)
                    end
                    sendCef('documents.changePage|4')
                elseif data.type == 4 then
                    if data.zavisimost then
                        sobes.narko = tonumber(data.zavisimost)
                    else
                        sobes.narko = 'Отсутствует мед. карта'
                    end
                    sendCef('documents.close')
                end
            end
        end
    end
end
function sendCef(str)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #str)
    raknetBitStreamWriteString(bs, str)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

function update_search()
    local query_utf8 = ffi.string(search_query)
    local query = u8:decode(query_utf8):lower()
    
    if query == "" then
        filtered_ads = ads
        return
    end
    
    local res = {}
    for _, ad in ipairs(ads) do
        if (ad.text and u8:decode(ad.text):lower():find(query, 1, true)) or 
           (ad.my_text and u8:decode(ad.my_text):lower():find(query, 1, true)) then
            table.insert(res, ad)
        end
    end
    filtered_ads = res
end
function load_ads()
    local loaded = load_json(config_path .. 'advertisement.json')
    if loaded then
        ads = loaded
        update_search()
    end
end
function save_ads()
    if not save_json(config_path .. 'advertisement.json', ads) then
        cLog('Не удалось сохранить историю объявлений. Сообщите разработчику! (save_ads)')
        return false
    end
    return true
end
function convert_old_ads()
    local cfg_file = getWorkingDirectory() .. "\\config\\News Helper\\advertisement.cfg"
    if doesFileExist(cfg_file) then
        local file = io.open(cfg_file, "r")
        if not file then return end
        local content = file:read("*a")
        file:close()
        
        local old_ads = nil
        local lua_func = loadstring(content)
        if lua_func then
            local success, res = pcall(lua_func)
            if success then old_ads = res end
        end
        
        if not old_ads or type(old_ads) ~= 'table' then
            lua_func = loadstring("return " .. content)
            if lua_func then
                local success, res = pcall(lua_func)
                if success then old_ads = res end
            end
        end

        if old_ads and type(old_ads) == 'table' then
            local converted_count = 0
            for _, v in pairs(old_ads) do
                if type(v) == 'table' and v.ad and v.text then
                    local exists = false
                    for _, existing in ipairs(ads) do
                        if existing.text == v.ad then
                            exists = true
                            break
                        end
                    end
                    if not exists then
                        table.insert(ads, { text = v.ad, my_text = v.text })
                        converted_count = converted_count + 1
                    end
                end
            end
            if converted_count > 0 then
                save_ads()
                cLog('Конвертировано ' .. converted_count .. ' объявлений из advertisement.cfg')
            end
            os.remove(cfg_file)
        end
    end
end


function load_stats()
    local loaded = load_json(config_path .. 'stats.json')
    if loaded then stats = loaded end
end
function save_stats()
    save_json(config_path .. 'stats.json', stats)
end

local AI_TOGGLE = {}
function imgui.ToggleButton(str_id, value, size)
    local size = size or imgui.ImVec2(40, 20)
	local duration = 0.15
	local p = imgui.GetCursorScreenPos()
    local DL = imgui.GetWindowDrawList()
    local title = str_id:gsub('##.*$', '')
    local ts = imgui.CalcTextSize(title)
    local cols = {
    	enable = imgui.GetStyle().Colors[imgui.Col.ButtonActive],
    	disable = imgui.GetStyle().Colors[imgui.Col.TextDisabled]	
    }
    local radius = 6
    local o = {
    	x = 4,
    	y = p.y + (size.y / 2)
    }
    local A = imgui.ImVec2(p.x + radius + o.x, o.y)
    local B = imgui.ImVec2(p.x + size.x - radius - o.x, o.y)

    if AI_TOGGLE[str_id] == nil then
        AI_TOGGLE[str_id] = {
        	clock = nil,
        	color = value[0] and cols.enable or cols.disable,
        	pos = value[0] and B or A
        }
    end
    local pool = AI_TOGGLE[str_id]
    
    imgui.BeginGroup()
	    local pos = imgui.GetCursorPos()
	    local result = imgui.InvisibleButton(str_id, imgui.ImVec2(size.x, size.y))
	    if result then
	        value[0] = not value[0]
	        pool.clock = os.clock()
	    end
	    if #title > 0 then
		    local spc = imgui.GetStyle().ItemSpacing
		    imgui.SetCursorPos(imgui.ImVec2(pos.x + size.x + spc.x, pos.y + ((size.y - ts.y) / 2)))
	    	imgui.Text(title)
    	end
    imgui.EndGroup()

 	if pool.clock and os.clock() - pool.clock <= duration then
        pool.color = imgui.bringVec4To(
            imgui.ImVec4(pool.color),
            value[0] and cols.enable or cols.disable,
            pool.clock,
            duration
        )

        pool.pos = imgui.bringVec2To(
        	imgui.ImVec2(pool.pos),
        	value[0] and B or A,
        	pool.clock,
            duration
        )
    else
        pool.color = value[0] and cols.enable or cols.disable
        pool.pos = value[0] and B or A
    end

	DL:AddRect(p, imgui.ImVec2(p.x + size.x, p.y + size.y), imgui.ColorConvertFloat4ToU32(pool.color), 10, 15, 1)
	DL:AddCircleFilled(pool.pos, radius, imgui.ColorConvertFloat4ToU32(pool.color))

    return result
end
local AI_HEADERBUT = {}
function imgui.HeaderButton(bool, str_id) -- addons
	local DL = imgui.GetWindowDrawList()
	local result = false
	local label = string.gsub(str_id, "##.*$", "")
	local duration = { 0.25, 0.15 }
	local cols = {
        idle = imgui.GetStyle().Colors[imgui.Col.TextDisabled],
        hovr = imgui.GetStyle().Colors[imgui.Col.Text],
        slct = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
    }

 	if not AI_HEADERBUT[str_id] then
        AI_HEADERBUT[str_id] = {
            color = bool and cols.slct or cols.idle,
            clock = os.clock() + duration[1],
            h = {
                state = bool,
                alpha = bool and 1.00 or 0.00,
                clock = os.clock() + duration[2],
            }
        }
    end
    local pool = AI_HEADERBUT[str_id]

	imgui.BeginGroup()
		local pos = imgui.GetCursorPos()
		local p = imgui.GetCursorScreenPos()
		
        if font[18] then imgui.PushFont(font[18]) end
		imgui.TextColored(pool.color, label)
        if font[18] then imgui.PopFont() end
		local s = imgui.GetItemRectSize()

        if s.x == 0 and s.y == 0 then s = imgui.ImVec2(100, 20) end
		
        local hovered = false
        if p and s then
            hovered = imgui.isPlaceHovered(p, imgui.ImVec2(p.x + s.x, p.y + s.y))
        end

		local clicked = imgui.IsItemClicked()
		
		if pool.h.state ~= hovered and not bool then
			pool.h.state = hovered
			pool.h.clock = os.clock()
		end
		
		if clicked then
	    	pool.clock = os.clock()
	    	result = true
	    end

    	if os.clock() - pool.clock <= duration[1] then
			pool.color = imgui.bringVec4To(
				imgui.ImVec4(pool.color),
				bool and cols.slct or (hovered and cols.hovr or cols.idle),
				pool.clock,
				duration[1]
			)
		else
			pool.color = bool and cols.slct or (hovered and cols.hovr or cols.idle)
		end

		if pool.h.clock ~= nil then
			if os.clock() - pool.h.clock <= duration[2] then
				pool.h.alpha = imgui.bringFloatTo(
					pool.h.alpha,
					pool.h.state and 1.00 or 0.00,
					pool.h.clock,
					duration[2]
				)
			else
				pool.h.alpha = pool.h.state and 1.00 or 0.00
				if not pool.h.state then
					pool.h.clock = nil
				end
			end
            
            if s and s.x then
			    local max = s.x / 2
			    local Y = p.y + s.y + 3
			    local mid = p.x + max

			    DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid + (max * pool.h.alpha), Y), imgui.GetColorU32Vec4(imgui.set_alpha(pool.color, pool.h.alpha)), 3)
			    DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid - (max * pool.h.alpha), Y), imgui.GetColorU32Vec4(imgui.set_alpha(pool.color, pool.h.alpha)), 3)
            end
		end

	imgui.EndGroup()
	return result
end
function imgui.RenderText(text)
	local style = imgui.GetStyle()
    local colors = style.Colors
    local col = imgui.Col
	local width = imgui.GetWindowWidth()

	local score = {}
	for tab in string.gmatch(text, '[^\t]+') do score[#score + 1] = tab end

	for i=1, #score do
		if i ~= 1 then 
			if #score == 2 then
				imgui.SameLine(0)
				imgui.SetCursorPosX((width / #score * (i - 1)) + (width / (#score * 2)) + 10)
			else 
				imgui.SameLine(0)
				local text_width = imgui.CalcTextSize(tostring(string.gsub(score[i], '{%x%x%x%x%x%x}', '')))
				imgui.SetCursorPosX((width / #score * (i - 1)) + (width / (#score * 2)) - (text_width.x / 2) - 10)
			end
		end

		local text = score[i]:gsub('{(%x%x%x%x%x%x)}', '{%1FF}')
		local color = colors[col.Text]
		local start = 1
		local a, b = text:find('{........}', start)	

		while a do
			local t = text:sub(start, a - 1)
			if #t > 0 then
				imgui.TextColored(color, t)
				imgui.SameLine(nil, 0)
			end

			local clr = text:sub(a + 1, b - 1)
			if clr:upper() == 'STANDART' then color = colors[col.Text]
			else
				clr = tonumber(clr, 16)
				if clr then
					local r = bit.band(bit.rshift(clr, 24), 0xFF)
					local g = bit.band(bit.rshift(clr, 16), 0xFF)
					local b = bit.band(bit.rshift(clr, 8), 0xFF)
					local a = bit.band(clr, 0xFF)
					color = imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
				end
			end

			start = b + 1
			a, b = text:find('{........}', start)
		end
		imgui.NewLine()
		if #text >= start then
			imgui.SameLine(nil, 0)
			imgui.TextColored(color, text:sub(start))
		end

	end
end
function imgui.Hint(str_id, hint, delay) -- https://www.blast.hk/threads/13380/post-551583
    local hovered = imgui.IsItemHovered()
    local animTime = 0.15
    local delay = delay or 0.00
    local show = true
    if not str_id then str_id = math.randomseed(os.time()) end

    if not allHints then allHints = {} end
    if not allHints[str_id] then
        allHints[str_id] = {
            status = false,
            timer = 0
        }
    end

    if hovered then
        for k, v in pairs(allHints) do
            if k ~= str_id and os.clock() - v.timer <= animTime  then
                show = false
            end
        end
    end

    if show and allHints[str_id].status ~= hovered then
        allHints[str_id].status = hovered
        allHints[str_id].timer = os.clock() + delay
    end

    if show then
        local between = os.clock() - allHints[str_id].timer
        if between <= animTime then
            local s = function(f)
                return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
            end
            local alpha = hovered and s(between / animTime) or s(1.00 - between / animTime)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
            imgui.BeginTooltip()
            local info_icon = fa('CIRCLE_INFO')
            imgui.Text((type(info_icon) == 'string' and info_icon or '!') .. ' ' .. tostring(hint))
            imgui.EndTooltip()
            imgui.PopStyleVar()
        elseif hovered then
            local info_icon = fa('CIRCLE_INFO')
            imgui.SetTooltip((type(info_icon) == 'string' and info_icon or '!') .. ' ' .. hint)
        end
    end
end
function imgui.CustomMenu(items, selected_idx, btn_size)
    local draw_list = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local x, y = p.x, p.y
    local spacing = 5
    local total_height = #items * (btn_size.y + spacing)
    local avail_h = imgui.GetContentRegionAvail().y
    local offset_y = math.max(0, (avail_h - total_height) / 2)
    imgui.SetCursorPosY(imgui.GetCursorPosY() + offset_y)
    y = y + offset_y
    for i, item_data in ipairs(items) do
        local icon, label = item_data[1], item_data[2]
        if not anims.menu_btns[i] then anims.menu_btns[i] = 0 end
        local is_selected = (selected_idx[0] == i)
        local target = is_selected and 1 or 0
        local hovered = false
        imgui.PushIDInt(i)
        if imgui.IsMouseHoveringRect(imgui.ImVec2(x, y), imgui.ImVec2(x + btn_size.x, y + btn_size.y)) then
            hovered = true
        end
        local hover_anim = anims.menu_btns[i]
        local off_x = hover_anim * 4
        local off_y = 0.2
        
        imgui.SetCursorScreenPos(imgui.ImVec2(x + off_x, y + off_y))
        
        if imgui.InvisibleButton(label, btn_size) then
            selected_idx[0] = i
            anims.content_alpha = 0 
        end
        hovered = imgui.IsItemHovered()
        if hovered then target = is_selected and 1 or 1 end
        
        local current = anims.menu_btns[i]
        local factor = (target > current) and 0.25 or 0.35
        anims.menu_btns[i] = current + (target - current) * factor
        local progress = anims.menu_btns[i]
        
        local alpha_style = imgui.GetStyle().Alpha
        if progress > 0.01 then
            local theme_acc = cfg.theme.Accent or {0.28, 0.38, 0.58, 1.0}
            local r, g, b = theme_acc[1], theme_acc[2], theme_acc[3]
            local glow_col = imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, 0.3 * progress * alpha_style))
            draw_list:AddRectFilled(imgui.ImVec2(x + off_x - 3, y + off_y - 3), imgui.ImVec2(x + off_x + btn_size.x + 3, y + off_y + btn_size.y + 3), glow_col, 10.0)
            
            local col = imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, (0.2 + 0.4 * progress) * alpha_style))
            if is_selected then col = imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, 0.7 * alpha_style)) end
            draw_list:AddRectFilled(imgui.ImVec2(x + off_x, y + off_y), imgui.ImVec2(x + off_x + btn_size.x, y + off_y + btn_size.y), col, 8.0)
        end
        
        local text_color = imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, alpha_style))
        if font[18] then imgui.PushFont(font[18]) end
        local icon_size = imgui.CalcTextSize(icon)
        local label_size = imgui.CalcTextSize(label)
        draw_list:AddText(imgui.ImVec2(x + off_x + 15, y + off_y + (btn_size.y - icon_size.y) / 2), text_color, icon)
        draw_list:AddText(imgui.ImVec2(x + off_x + 45, y + off_y + (btn_size.y - label_size.y) / 2), text_color, label)
        if font[18] then imgui.PopFont() end
        
        y = y + btn_size.y + spacing
        imgui.PopID()
    end
end
function imgui.LoaderButton(isLoading, label, size)
    local bit = require 'bit'
    size = size or imgui.ImVec2(0, 0)
    if not isLoading then
        return imgui.Button(label, size)
    end
    local draw = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.GetStyle().Colors[imgui.Col.Button])
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.GetStyle().Colors[imgui.Col.Button])
    imgui.Button("##loader", size)
    local btnSize = imgui.GetItemRectSize()
    imgui.PopStyleColor(2)
    local t = os.clock() * 0.8
    local start = math.rad((t * 360) % 360)
    local sweep = math.rad(270)
    local c = imgui.GetStyle().Colors[imgui.Col.Text]
    local col = bit.bor(
        bit.lshift(math.floor(c.w * 255), 24),
        bit.lshift(math.floor(c.x * 255), 16),
        bit.lshift(math.floor(c.y * 255), 8),
        math.floor(c.z * 255)
    )

    local center = imgui.ImVec2(pos.x + btnSize.x / 2, pos.y + btnSize.y / 2)
    local radius = math.max(6, btnSize.y / 2 - 10)

    draw:PathClear()
    draw:PathArcTo(center, radius, start, start + sweep, 48)
    draw:PathStroke(col, false, 2)

    return false
end
function imgui.TextColoredRGB(text)
    local style = imgui.GetStyle()
    local colors = style.Colors
    local ImVec4 = imgui.ImVec4
    local explode_argb = function(argb)
        local a = bit.band(bit.rshift(argb, 24), 0xFF)
        local r = bit.band(bit.rshift(argb, 16), 0xFF)
        local g = bit.band(bit.rshift(argb, 8), 0xFF)
        local b = bit.band(argb, 0xFF)
        return a, r, g, b
    end
    local getcolor = function(color)
        if color:sub(1, 6):upper() == 'SSSSSS' then
            local r, g, b = colors[1].x, colors[1].y, colors[1].z
            local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
            return ImVec4(r, g, b, a / 255)
        end
        local color = type(color) == 'string' and tonumber(color, 16) or color
        if type(color) ~= 'number' then return end
        local r, g, b, a = explode_argb(color)
        return imgui.ImVec4(r/255, g/255, b/255, a/255)
    end
    local render_text = function(text_)
        for w in text_:gmatch('[^\r\n]+') do
            local text, colors_, m = {}, {}, 1
            w = w:gsub('{(......)}', '{%1FF}')
            while w:find('{........}') do
                local n, k = w:find('{........}')
                local color = getcolor(w:sub(n + 1, k - 1))
                if color then
                    text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
                    colors_[#colors_ + 1] = color
                    m = n
                end
                w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
            end
            if text[0] then
                for i = 0, #text do
                    imgui.TextColored(colors_[i] or colors[1], text[i])
                    imgui.SameLine(nil, 0)
                end
                imgui.NewLine()
            else imgui.Text(w) end
        end
    end
    render_text(text)
end
function imgui.isPlaceHovered(a, b) -- addons
	local m = imgui.GetMousePos()
	if m.x >= a.x and m.y >= a.y then
		if m.x <= b.x and m.y <= b.y then
			return true
		end
	end
	return false
end
function imgui.bringVec4To(from, to, start_time, duration) -- addons
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec4(
            from.x + (count * (to.x - from.x) / 100),
            from.y + (count * (to.y - from.y) / 100),
            from.z + (count * (to.z - from.z) / 100),
            from.w + (count * (to.w - from.w) / 100)
        ), true
    end
    return (timer > duration) and to or from, false
end
function imgui.bringVec2To(from, to, start_time, duration) -- addons
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec2(
            from.x + (count * (to.x - from.x) / 100),
            from.y + (count * (to.y - from.y) / 100)
        ), true
    end
    return (timer > duration) and to or from, false
end
function imgui.bringFloatTo(from, to, start_time, duration) -- addons
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return from + (count * (to - from) / 100), true
    end
    return (timer > duration) and to or from, false
end
function imgui.set_alpha(color, alpha) -- addons
	alpha = alpha and imgui.limit(alpha, 0.0, 1.0) or 1.0
	return imgui.ImVec4(color.x, color.y, color.z, alpha)
end
function imgui.limit(v, min, max) -- addons
	min = min or 0.0
	max = max or 1.0
	return v < min and min or (v > max and max or v)
end
function HotkeyButton(title, bind_name)
    local b_keys = cfg.binds[bind_name] or {}
    if not hotkey.List[bind_name] then
        hotkey.RegisterHotKey(bind_name, false, b_keys)
    end
    
    if hotkey.ShowHotKey(bind_name, imgui.ImVec2(100, 25)) then
        cfg.binds[bind_name] = hotkey.List[bind_name].keys
        save_config()
    end
    
    imgui.SameLine()
    imgui.Text(title)
end
function imgui.TextCenter(text)
	text = tostring(text)
	imgui.SetCursorPosX(imgui.GetWindowWidth() / 2  - imgui.CalcTextSize(tostring(text:gsub('{%x%x%x%x%x%x%x?%x?}', ''):gsub('{STANDART}', ''))).x / 2 - 2)
	imgui.Text(text)
end
function drawActivityGraph(x, y, width, height, activityData, maxValue, mainColor, titleText)
    local draw_list = imgui.GetWindowDrawList()
    local bgColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(0.12, 0.12, 0.15, 0.6))
    draw_list:AddRectFilled(imgui.ImVec2(x, y), imgui.ImVec2(x + width, y + height), bgColor, 6)
    local gridColor = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(1, 1, 1, 0.05))
    local topPadding = 30
    local bottomPadding = 25
    local graphDrawHeight = height - topPadding - bottomPadding
    
    for i = 0, 3 do
        local lineY = y + topPadding + (graphDrawHeight / 3) * i
        draw_list:AddLine(imgui.ImVec2(x + 5, lineY), imgui.ImVec2(x + width - 5, lineY), gridColor, 1)
    end

    local total = 0
    for _, act in ipairs(activityData) do total = total + act.value end

    draw_list:AddText(imgui.ImVec2(x + 10, y + 8), 0xFFAAAAAA, titleText or "")
    
    local totalText = string.format("Всего: %s %s", formatNumber(total), activityData[1] and activityData[1].unit or "")
    local totalSize = imgui.CalcTextSize(totalText)
    draw_list:AddText(imgui.ImVec2(x + width - totalSize.x - 10, y + 8), 0xFFAAAAAA, totalText)
    local barWidth = (width - 20) / #activityData
    local maxVal = maxValue > 0 and maxValue or 1
    
    for i, activity in ipairs(activityData) do
        local barHeight = (activity.value / maxVal) * graphDrawHeight
        if barHeight < 2 and activity.value > 0 then barHeight = 2 end
        
        local barX = x + 10 + (i - 1) * barWidth
        local barBottomY = y + height - bottomPadding
        local barTopY = barBottomY - barHeight
        local isHovered = imgui.IsMouseHoveringRect(imgui.ImVec2(barX, y + topPadding), imgui.ImVec2(barX + barWidth, barBottomY))
        local r, g, b = mainColor.x, mainColor.y, mainColor.z
        if isHovered then
            r, g, b = math.min(1, r + 0.2), math.min(1, g + 0.2), math.min(1, b + 0.2)
        end
        local barCol = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(r, g, b, 0.9))
        local barColDark = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(r*0.5, g*0.5, b*0.5, 0.7))

        if activity.value > 0 then
            draw_list:AddRectFilled(imgui.ImVec2(barX + 3, barTopY), imgui.ImVec2(barX + barWidth - 3, barBottomY), barCol, 3)
            draw_list:AddRect(imgui.ImVec2(barX + 3, barTopY), imgui.ImVec2(barX + barWidth - 3, barBottomY), barColDark, 3, 15, 1)
        end
        local textSize = imgui.CalcTextSize(activity.day)
        local textColor = isHovered and 0xFFFFFFFF or 0xFF888888
        draw_list:AddText(imgui.ImVec2(barX + (barWidth / 2) - (textSize.x / 2), barBottomY + 4), textColor, activity.day)
        if isHovered then
            imgui.BeginTooltip()
            imgui.TextColored(imgui.ImVec4(r, g, b, 1), activity.full_date)
            imgui.Separator()
            imgui.Text(string.format("Значение: %s %s", formatNumber(activity.value), activity.unit))
            imgui.EndTooltip()
        end
    end
end
function apply_style()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local t = cfg.theme
    style.WindowRounding = 10.0
    style.ChildRounding = 8.0
    style.FrameRounding = 8.0
    style.PopupRounding = 8.0
    style.ScrollbarRounding = 8.0
    style.GrabRounding = 8.0
    style.TabRounding = 8.0
    style.WindowBorderSize = 0.0
    style.FrameBorderSize = 0.0
    style.PopupBorderSize = 0.0
    style.ChildBorderSize = 1.0
    
    local function copyColor(targetEnum, sourceTable)
        if sourceTable and type(sourceTable) == 'table' and #sourceTable == 4 then
            colors[targetEnum] = ImVec4(unpack(sourceTable))
        end
    end

    copyColor(clr.WindowBg, t.WindowBg)
    copyColor(clr.ChildBg, t.ChildBg)
    copyColor(clr.PopupBg, t.PopupBg)
    copyColor(clr.Border, t.Border)
    copyColor(clr.FrameBg, t.FrameBg)
    copyColor(clr.FrameBgHovered, t.FrameBgHovered)
    copyColor(clr.FrameBgActive, t.FrameBgActive)
    copyColor(clr.TitleBg, t.TitleBg)
    copyColor(clr.Button, t.Button)
    copyColor(clr.ButtonHovered, t.ButtonHovered)
    copyColor(clr.ButtonActive, t.ButtonActive)
    copyColor(clr.Text, t.Text)
    copyColor(clr.Header, t.Header)
end
function check_update()
    cheking_update = true
    downloadUrlToFile('https://raw.githubusercontent.com/Faiserx/News-Helper/refs/heads/main/update.ini', config_path .. "/update.ini", function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local f = io.open(config_path .. "/update.ini", 'r')
            local vers, vers_text
            if f then
                local content = f:read('*a')
                vers = content:match('vers=([^\n]+)')
                vers_text = content:match('vers_text=([^\n]+)')
                if vers then vers = vers:gsub('\r', '') end
                if vers_text then vers_text = vers_text:gsub('\r', '') end
                f:close()
            end
            if vers then
                if tonumber(vers) > tonumber(thisScript().version) then
                    sampAddChatMessage(u8:decode(tag .. 'Обнаружена новая версия скрипта: ' .. vers .. '! Подробности смотрите в меню.'), 0x008080)
                    notif('info', 'News Helper', u8:decode('Обнаружено обновление!'), 4000)
                    update_found = true
                    changelog = vers_text
                    cheking_update = false
				else
					notif('info', 'News Helper', u8:decode('Обновление не найдено!'), 4000)
                    cheking_update = false
                end
            else
                sampAddChatMessage(u8:decode(tag .. 'Ошибка проверки обновления. Попробуйте еще раз!'), 0x008080)
                notif('error', 'News Helper', u8:decode('Ошибка проверки обновления!'), 4000)
                cheking_update = false
            end
            os.remove(config_path .. "/update.ini")
        elseif status == dlstatus.STATUS_ERROR then
            sampAddChatMessage(u8:decode(tag .. 'Ошибка проверки обновления. Попробуйте еще раз!'), 0x008080)
            notif('error', 'News Helper', u8:decode('Ошибка проверки обновления!'), 4000)
            cheking_update = false
        end
    end)
end
addEventHandler('onWindowMessage', function(msg, k, lparam)
    if msg == 0x0006 then
        if hotkey and hotkey.ActiveKeys then
             hotkey.ActiveKeys = {}
        end
    end
    if msg == 0x100 and k == 0x1B then
        if hotkey and hotkey.ActiveKeys then
             hotkey.ActiveKeys = {}
        end
        if (win.main and win.main[0]) or (win.helper and win.helper[0]) or (suggestion.window and suggestion.window[0]) then
            if win.main and win.main[0] then anims.main_target = false end
            if win.helper and win.helper[0] then anims.helper_target = false end
            if suggestion.window and suggestion.window[0] then anims.sugg_target = false end
            consumeWindowMessage(true, true)
        end
    end
end) 
