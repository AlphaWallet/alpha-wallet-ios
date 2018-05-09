//
//  AssetDefinitionXML.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation

class AssetDefinitionXML {
    
    // swiftlint:disable:next line_length
    public static let assetDefinition = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<asset>\n" +
    "  <contract>\n" +
    "    <address type=\"issuing\">0x277b1318965030C62E1dAc9671a6F8dF77F855Cf</address>\n" +
    "    <name lang=\"ru\">2018 Билеты</name>\n" +
    "    <name lang=\"en\">2018 Tickets</name>\n" +
    "    <name lang=\"zh\">2018承兑票</name>\n" +
    "    <name lang=\"es\">Entradas de 2018</name>\n" +
    "    <network>1</network> <!-- MAINNET -->\n" +
    "  </contract>\n" +
    "  <!-- consider metadata of tokens, e.g. quantifier in each languages -->\n" +
    "  <features>\n" +
    "    <feature bitmask=\"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\">\n" +
    "      <trade method=\"market-queue\" version=\"0.1\">\n" +
    "        <gateway>https://482kdh4npg.execute-api.ap-southeast-1.amazonaws.com/dev/</gateway>\n" +
    "      </trade>\n" +
    "      <trade method=\"universal-link\" version=\"9\">\n" +
    "        <prefix>https://app.awallet.io/</prefix>\n" +
    "      </trade>\n" +
    "      <feemaster>" + Constants.paymentServer + "</feemaster>\n" +
    "      <redeem>\n" +
    "        <method name=\"QR\"/>\n" +
    "        <!--\n" +
    "        <method name=\"Aztec\"/>\n" +
    "        <method name=\"Bluetooth\"/>\n" +
    "        -->\n" +
    "      </redeem>\n" +
    "    </feature>\n" +
    "  </features>\n" +
    "  <ordering>\n" +
    "    <order bitmask=\"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\" name=\"default\">\n" +
    "      <byName field=\"locality\"/>\n" +
    "      <byValue field=\"match\" />\n" +
    "      <byValue field=\"number\" />\n" +
    "    </order>\n" +
    "    <order bitmask=\"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\" name=\"concise\">\n" +
    "      <byValue field=\"match\"/>\n" +
    "      <byValue field=\"category\"/>\n" +
    "      <byValue field=\"number\"/>\n" +
    "    </order>\n" +
    "  </ordering>\n" +
    "\n" +
    "  <!-- token UI definition can happen here -->\n" +
    "  <fields>\n" +
    "    <!--\n" +
    "    There are 64 matches (1-64), each has up to 16 ticket classes,\n" +
    "    within each class, there are less than 65536 tickets.  A compact\n" +
    "    format identifier would consist of 26 bits:\n" +
    "    [6] [4] [16]\n" +
    "    Representing:\n" +
    "\t    Match ID: 1-64\n" +
    "\t    Class: 1-16\n" +
    "\t    Seat: 0-65536\n" +
    "    These are represented by 7 hex codes. Therefore 0x40F0481 means\n" +
    "    the final match (64th), class F (highest) ticket number 1153. But\n" +
    "    we didn't end up using this compatct form.\n" +
    "    Information about a match, like Venue, City, Date, which team\n" +
    "    against which, can all be looked up by MatchID. There are\n" +
    "    advantages and disadvantages in encoding them by a look up table\n" +
    "    or by a bit field.\n" +
    "    The advantage of storing them as a bit field is that one can\n" +
    "    enquiry the range of it in the market queue server without the\n" +
    "    server kowing the meaning of the bitfields. Furthermore it make\n" +
    "    the android and ios library which accesses the XML file a bit\n" +
    "    easier to write, but at the cost that the ticket issuing\n" +
    "    (authorisation) server is a bit more complicated.\n" +
    "    For now we decide to use bit-fields.  The fields, together with\n" +
    "    its bitwidth or byte-width are represented in this table:\n" +
    "    Fields:           City,   Venue,  Date,   TeamA,  TeamB,  Match, Category\n" +
    "    Maximum, 2018:    11,     12,     32,     32,     32,     64,    16\n" +
    "    Maximum, all time:64,     64,     64,     32,     32,     64,    64\n" +
    "    Bitwidth:         6,      6,      6,      5,      5,      6,     6\n" +
    "    Bytewidth:        1,      1,      4,      3,      3,      1,     1,\n" +
    "    In practise, because this XML file is used in 3 to 4 places\n" +
    "    (authorisation server, ios, android, potentially market-queue),\n" +
    "    Weiwu thought that it helps the developers if we use byte-fields\n" +
    "    instead of bit-fields.\n" +
    "  -->\n" +
    "    <field bitmask=\"00000000000000000000000000000000FF000000000000000000000000000000\" id=\"locality\"\n" +
    "\t   type=\"Enumeration\">\n" +
    "      <name lang=\"ru\">город</name>\n" +
    "      <name lang=\"en\">City</name>\n" +
    "      <name lang=\"zh\">城市</name>\n" +
    "      <name lang=\"es\">Ciudad</name>\n" +
    "      <mapping>\n" +
    "        <entity key=\"1\">\n" +
    "          <name lang=\"ru\">Москва́</name>\n" +
    "          <name lang=\"en\">Moscow</name>\n" +
    "          <name lang=\"zh\">莫斯科</name>\n" +
    "          <name lang=\"es\">Moscú</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"2\">\n" +
    "          <name lang=\"ru\">Санкт-Петербу́рг</name>\n" +
    "          <name lang=\"en\">Saint Petersburg</name>\n" +
    "          <name lang=\"zh\">圣彼得堡</name>\n" +
    "          <name lang=\"es\">San Petersburgo</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"3\">\n" +
    "          <name lang=\"ru\">сочи</name>\n" +
    "          <name lang=\"en\">Sochi</name>\n" +
    "          <name lang=\"zh\">索契</name>\n" +
    "          <name lang=\"es\">Sochi</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"4\">\n" +
    "          <name lang=\"ru\">екатеринбург</name>\n" +
    "          <name lang=\"en\">Ekaterinburg</name>\n" +
    "          <name lang=\"zh\">叶卡捷琳堡</name>\n" +
    "          <name lang=\"es\">Ekaterinburg</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"5\">\n" +
    "          <name lang=\"ru\">Саранск</name>\n" +
    "          <name lang=\"en\">Saransk</name>\n" +
    "          <name lang=\"zh\">萨兰斯克</name>\n" +
    "          <name lang=\"es\">Saransk</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"6\">\n" +
    "          <name lang=\"ru\">казань</name>\n" +
    "          <name lang=\"en\">Kazan</name>\n" +
    "          <name lang=\"zh\">喀山</name>\n" +
    "          <name lang=\"es\">Kazan</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"7\">\n" +
    "          <name lang=\"ru\">Нижний Новгород</name>\n" +
    "          <name lang=\"en\">Nizhny Novgorod</name>\n" +
    "          <name lang=\"zh\">下诺夫哥罗德</name>\n" +
    "          <name lang=\"es\">Nizhny Novgorod</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"8\">\n" +
    "          <name lang=\"ru\">Ростов-на-Дону</name>\n" +
    "          <name lang=\"en\">Rostov-on-Don</name>\n" +
    "          <name lang=\"zh\">顿河畔罗斯托夫</name>\n" +
    "          <name lang=\"es\">Rostov-on-Don</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"9\">\n" +
    "          <name lang=\"ru\">Самара</name>\n" +
    "          <name lang=\"en\">Samara</name>\n" +
    "          <name lang=\"zh\">翅果</name>\n" +
    "          <name lang=\"es\">Samara</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"10\">\n" +
    "          <name lang=\"ru\">Волгоград</name>\n" +
    "          <name lang=\"en\">Volgograd</name>\n" +
    "          <name lang=\"zh\">伏尔加格勒</name>\n" +
    "          <name lang=\"es\">Volgogrado</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"11\">\n" +
    "          <name lang=\"ru\">Калининград</name>\n" +
    "          <name lang=\"en\">Kaliningrad</name>\n" +
    "          <name lang=\"zh\">加里宁格勒</name>\n" +
    "          <name lang=\"es\">Kaliningrad</name>\n" +
    "        </entity>\n" +
    "      </mapping>\n" +
    "    </field>\n" +
    "    <field bitmask=\"0000000000000000000000000000000000FF0000000000000000000000000000\" id=\"venue\"\n" +
    "\t   type=\"Enumeration\">\n" +
    "      <name lang=\"ru\">место встречи</name>\n" +
    "      <name lang=\"en\">Venue</name>\n" +
    "      <name lang=\"zh\">场馆</name>\n" +
    "      <name lang=\"es\">Lugar</name>\n" +
    "      <mapping>\n" +
    "        <entity key=\"1\">\n" +
    "          <name lang=\"ru\">Стадион Калининград</name>\n" +
    "          <name lang=\"en\">Kaliningrad Stadium</name>\n" +
    "          <name lang=\"zh\">加里寧格勒體育場</name>\n" +
    "          <name lang=\"es\">Estadio de Kaliningrado</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"2\">\n" +
    "          <name lang=\"ru\">Екатеринбург Арена</name>\n" +
    "          <name lang=\"en\">Volgograd Arena</name>\n" +
    "          <name lang=\"zh\">伏爾加格勒體育場</name>\n" +
    "          <name lang=\"es\">Volgogrado Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"3\">\n" +
    "          <name lang=\"ru\">Казань Арена</name>\n" +
    "          <name lang=\"en\">Ekaterinburg Arena</name>\n" +
    "          <name lang=\"zh\">加里宁格勒体育场</name>\n" +
    "          <name lang=\"es\">Ekaterimburgo Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"4\">\n" +
    "          <name lang=\"ru\">Мордовия Арена</name>\n" +
    "          <name lang=\"en\">Fisht Stadium</name>\n" +
    "          <name lang=\"zh\">菲什特奧林匹克體育場</name>\n" +
    "          <name lang=\"es\">Estadio Fisht</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"5\">\n" +
    "          <name lang=\"ru\">Ростов Арена</name>\n" +
    "          <name lang=\"en\">Kazan Arena</name>\n" +
    "          <name lang=\"zh\">喀山體育場</name>\n" +
    "          <name lang=\"es\">Kazan Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"6\">\n" +
    "          <name lang=\"ru\">Самара Арена</name>\n" +
    "          <name lang=\"en\">Nizhny Novgorod Stadium</name>\n" +
    "          <name lang=\"zh\">下諾夫哥羅德體育場</name>\n" +
    "          <name lang=\"es\">Estadio de Nizhni Novgorod</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"7\">\n" +
    "          <name lang=\"ru\">Стадион Калининград</name>\n" +
    "          <name lang=\"en\">Luzhniki Stadium</name>\n" +
    "          <name lang=\"zh\">卢日尼基体育场</name>\n" +
    "          <name lang=\"es\">Estadio Luzhniki</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"8\">\n" +
    "          <name lang=\"ru\">Стадион Лужники</name>\n" +
    "          <name lang=\"en\">Samara Arena</name>\n" +
    "          <name lang=\"zh\">薩馬拉體育場</name>\n" +
    "          <name lang=\"es\">Samara Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"9\">\n" +
    "          <name lang=\"ru\">Стадион Нижний Новгород</name>\n" +
    "          <name lang=\"en\">Rostov Arena</name>\n" +
    "          <name lang=\"zh\">羅斯托夫體育場</name>\n" +
    "          <name lang=\"es\">Rostov Arena</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"10\">\n" +
    "          <name lang=\"ru\">Стадион Спартак</name>\n" +
    "          <name lang=\"en\">Spartak Stadium</name>\n" +
    "          <name lang=\"zh\">斯巴達克體育場</name>\n" +
    "          <name lang=\"es\">Estadio del Spartak</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"11\">\n" +
    "          <name lang=\"ru\">Стадион Санкт-Петербург</name>\n" +
    "          <name lang=\"en\">Saint Petersburg Stadium</name>\n" +
    "          <name lang=\"zh\">十字架體育場</name>\n" +
    "          <name lang=\"es\">Estadio de San Petersburgo</name>\n" +
    "        </entity>\n" +
    "        <entity key=\"12\">\n" +
    "          <name lang=\"ru\">Стадион Фишт</name>\n" +
    "          <name lang=\"en\">Mordovia Arena</name>\n" +
    "          <name lang=\"zh\">莫爾多維亞體育場</name>\n" +
    "          <name lang=\"es\">Mordovia Arena</name>\n" +
    "        </entity>\n" +
    "      </mapping>\n" +
    "    </field>\n" +
    "    <field bitmask=\"000000000000000000000000000000000000FFFFFFFF00000000000000000000\" id=\"time\"\n" +
    "\t   type=\"BinaryTime\">\n" +
    "      <name lang=\"es\">время</name>\n" +
    "      <name lang=\"en\">Time</name>\n" +
    "      <name lang=\"zh\">时间</name>\n" +
    "      <name lang=\"es\">Tiempo</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"00000000000000000000000000000000000000000000FFFFFF00000000000000\" id=\"countryA\"\n" +
    "\t   type=\"IA5String\">\n" +
    "      <name lang=\"en\">Team A</name>\n" +
    "      <name lang=\"zh\">甲队</name>\n" +
    "      <name lang=\"es\">Equipo A</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"00000000000000000000000000000000000000000000000000FFFFFF00000000\" id=\"countryB\"\n" +
    "\t   type=\"IA5String\">\n" +
    "      <name lang=\"en\">Team B</name>\n" +
    "      <name lang=\"zh\">乙队</name>\n" +
    "      <name lang=\"es\">Equipo B</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"00000000000000000000000000000000000000000000000000000000FF000000\" id=\"match\"\n" +
    "\t   type=\"Integer\">\n" +
    "      <name lang=\"en\">Match</name>\n" +
    "      <name lang=\"zh\">场次</name>\n" +
    "      <name lang=\"es\">Evento</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"0000000000000000000000000000000000000000000000000000000000FF0000\" id=\"category\"\n" +
    "\t   type=\"Integer\">\n" +
    "      <name lang=\"en\">Cat</name>\n" +
    "      <name lang=\"zh\">等级</name>\n" +
    "      <name lang=\"es\">Cat</name>\n" +
    "    </field>\n" +
    "    <field bitmask=\"000000000000000000000000000000000000000000000000000000000000FFFF\" id=\"number\"\n" +
    "\t   type=\"Integer\">\n" +
    "      <name lang=\"en\">Number</name>\n" +
    "      <name lang=\"zh\">票号</name>\n" +
    "      <name lang=\"es\">Número</name>\n" +
    "    </field>\n" +
    "  </fields>\n" +
    "</asset>"
    
}
