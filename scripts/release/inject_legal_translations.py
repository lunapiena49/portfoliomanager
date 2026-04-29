"""Inject the legal/disclaimer i18n blocks into the 6 translation files.

ASCII-only on disk (CLAUDE.md rule). Localized strings carry diacritics
escaped as \\u sequences when needed -- json.dump(ensure_ascii=False)
keeps them human-readable on output, but the script source itself
stays ASCII.
"""

from __future__ import annotations

import json
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRANSLATIONS = ROOT / "assets" / "translations"

LANGS = ("it", "en", "es", "fr", "de", "pt")

LEGAL_DOCUMENTS_LABEL = {
    "it": "Documenti legali",
    "en": "Legal documents",
    "es": "Documentos legales",
    "fr": "Documents legaux",
    "de": "Rechtliche Dokumente",
    "pt": "Documentos legais",
}

LEGAL_BLOCKS = {
    "it": {
        "banner": {
            "ai_disclaimer": "I contenuti AI non sono consulenza finanziaria. Decisioni e responsabilita restano tue.",
        },
        "disclaimer": {
            "title": "Disclaimer finanziario",
            "intro": "Leggi attentamente prima di usare l'app. Conferma di aver compreso ogni punto.",
            "cta_accept": "Accetto e voglio continuare",
            "sections": {
                "no_advice": {
                    "title": "Non e consulenza finanziaria",
                    "body": "Portfolio Manager e uno strumento informativo. I contenuti e le analisi mostrati non costituiscono consulenza finanziaria, fiscale o legale ai sensi del TUF (D.Lgs. 58/1998) o di norme analoghe. Decidi sempre con un professionista abilitato.",
                },
                "ai_warning": {
                    "title": "Limiti dell'analisi AI",
                    "body": "Le risposte AI possono contenere errori, dati obsoleti o allucinazioni. Verifica sempre numeri, prezzi e raccomandazioni con fonti ufficiali. L'app non garantisce in alcun modo l'accuratezza degli output Gemini.",
                },
                "no_fiduciary": {
                    "title": "Nessun rapporto fiduciario",
                    "body": "L'uso dell'app non crea alcun rapporto di consulenza, gestione o intermediazione tra te e PluriFin. Non riceviamo mandato, non gestiamo capitali, non eseguiamo ordini per tuo conto.",
                },
                "risk": {
                    "title": "Rischio di mercato",
                    "body": "Gli investimenti possono perdere valore. Performance passate non garantiscono risultati futuri. Esposizione a strumenti complessi (derivati, leverage, crypto) puo comportare la perdita totale del capitale.",
                },
            },
            "checks": {
                "not_advice": "Capisco che l'app non fornisce consulenza finanziaria.",
                "not_fiduciary": "Capisco che PluriFin non gestisce i miei capitali.",
                "own_responsibility": "Mi assumo la responsabilita delle decisioni di investimento.",
            },
        },
        "documents": {
            "title": "Documenti legali",
            "copy": "Copia link",
            "url_copied": "Link copiato negli appunti.",
            "privacy": {
                "title": "Privacy Policy",
                "description": "Quali dati raccoglie l'app, dove vivono e come esercitare i tuoi diritti GDPR.",
            },
            "terms": {
                "title": "Termini di servizio",
                "description": "Condizioni d'uso dell'app, incluse le limitazioni di responsabilita.",
            },
            "disclaimer": {
                "title": "Disclaimer finanziario",
                "description": "Rileggi il testo del disclaimer accettato durante l'onboarding.",
            },
            "licenses": {
                "title": "Licenze open source",
                "description": "Elenco delle librerie di terze parti incluse nell'app.",
                "legalese": "Portfolio Manager (PluriFin) - Copyright (C) 2026 Filippo Salemi.",
            },
        },
    },
    "en": {
        "banner": {
            "ai_disclaimer": "AI content is not financial advice. Decisions and accountability remain yours.",
        },
        "disclaimer": {
            "title": "Financial disclaimer",
            "intro": "Read carefully before using the app. Confirm you understand each point.",
            "cta_accept": "I accept and want to continue",
            "sections": {
                "no_advice": {
                    "title": "Not financial advice",
                    "body": "Portfolio Manager is an informational tool. Content and analysis shown in the app are not financial, tax, or legal advice under the TUF (Italian D.Lgs. 58/1998) or comparable regulations. Always decide with a licensed professional.",
                },
                "ai_warning": {
                    "title": "Limits of AI analysis",
                    "body": "AI replies may contain errors, stale data, or hallucinations. Always verify numbers, prices, and recommendations with official sources. The app does not guarantee Gemini output accuracy.",
                },
                "no_fiduciary": {
                    "title": "No fiduciary relationship",
                    "body": "Using the app does not create any advisory, asset management, or brokerage relationship between you and PluriFin. We do not receive mandates, manage capital, or execute orders on your behalf.",
                },
                "risk": {
                    "title": "Market risk",
                    "body": "Investments may lose value. Past performance does not guarantee future results. Exposure to complex instruments (derivatives, leverage, crypto) may lead to total capital loss.",
                },
            },
            "checks": {
                "not_advice": "I understand the app does not provide financial advice.",
                "not_fiduciary": "I understand PluriFin does not manage my capital.",
                "own_responsibility": "I take responsibility for my investment decisions.",
            },
        },
        "documents": {
            "title": "Legal documents",
            "copy": "Copy link",
            "url_copied": "Link copied to clipboard.",
            "privacy": {
                "title": "Privacy Policy",
                "description": "What data the app collects, where it lives, and how to exercise your GDPR rights.",
            },
            "terms": {
                "title": "Terms of Service",
                "description": "Terms governing the use of the app, including liability limitations.",
            },
            "disclaimer": {
                "title": "Financial disclaimer",
                "description": "Re-read the disclaimer text accepted during onboarding.",
            },
            "licenses": {
                "title": "Open source licenses",
                "description": "List of third-party libraries bundled with the app.",
                "legalese": "Portfolio Manager (PluriFin) - Copyright (C) 2026 Filippo Salemi.",
            },
        },
    },
    "es": {
        "banner": {
            "ai_disclaimer": "El contenido de la IA no es asesoramiento financiero. Las decisiones y la responsabilidad son tuyas.",
        },
        "disclaimer": {
            "title": "Aviso financiero",
            "intro": "Lee con atencion antes de usar la app. Confirma que entiendes cada punto.",
            "cta_accept": "Acepto y quiero continuar",
            "sections": {
                "no_advice": {
                    "title": "No es asesoramiento financiero",
                    "body": "Portfolio Manager es una herramienta informativa. El contenido y los analisis mostrados en la app no son asesoramiento financiero, fiscal ni legal segun el TUF (D.Lgs. 58/1998 italiano) ni normas equivalentes. Decide siempre con un profesional habilitado.",
                },
                "ai_warning": {
                    "title": "Limites del analisis IA",
                    "body": "Las respuestas de IA pueden contener errores, datos obsoletos o alucinaciones. Verifica siempre numeros, precios y recomendaciones con fuentes oficiales. La app no garantiza la precision de Gemini.",
                },
                "no_fiduciary": {
                    "title": "Sin relacion fiduciaria",
                    "body": "El uso de la app no crea ninguna relacion de asesoramiento, gestion o intermediacion entre tu y PluriFin. No recibimos mandatos, no gestionamos capital, no ejecutamos ordenes por ti.",
                },
                "risk": {
                    "title": "Riesgo de mercado",
                    "body": "Las inversiones pueden perder valor. Rendimientos pasados no garantizan resultados futuros. La exposicion a instrumentos complejos (derivados, apalancamiento, cripto) puede causar la perdida total del capital.",
                },
            },
            "checks": {
                "not_advice": "Entiendo que la app no proporciona asesoramiento financiero.",
                "not_fiduciary": "Entiendo que PluriFin no gestiona mi capital.",
                "own_responsibility": "Asumo la responsabilidad de mis decisiones de inversion.",
            },
        },
        "documents": {
            "title": "Documentos legales",
            "copy": "Copiar enlace",
            "url_copied": "Enlace copiado al portapapeles.",
            "privacy": {
                "title": "Politica de privacidad",
                "description": "Que datos recopila la app, donde residen y como ejercer tus derechos RGPD.",
            },
            "terms": {
                "title": "Terminos de servicio",
                "description": "Condiciones de uso de la app, incluidas las limitaciones de responsabilidad.",
            },
            "disclaimer": {
                "title": "Aviso financiero",
                "description": "Vuelve a leer el aviso aceptado durante el onboarding.",
            },
            "licenses": {
                "title": "Licencias open source",
                "description": "Lista de las librerias de terceros incluidas en la app.",
                "legalese": "Portfolio Manager (PluriFin) - Copyright (C) 2026 Filippo Salemi.",
            },
        },
    },
    "fr": {
        "banner": {
            "ai_disclaimer": "Le contenu de l'IA n'est pas un conseil financier. Les decisions et la responsabilite vous appartiennent.",
        },
        "disclaimer": {
            "title": "Avertissement financier",
            "intro": "A lire attentivement avant d'utiliser l'app. Confirmez avoir compris chaque point.",
            "cta_accept": "J'accepte et je veux continuer",
            "sections": {
                "no_advice": {
                    "title": "Pas un conseil financier",
                    "body": "Portfolio Manager est un outil d'information. Le contenu et les analyses affiches dans l'app ne constituent pas un conseil financier, fiscal ou juridique au sens du TUF (D.Lgs. 58/1998 italien) ni de regles analogues. Decidez toujours avec un professionnel agree.",
                },
                "ai_warning": {
                    "title": "Limites de l'analyse IA",
                    "body": "Les reponses IA peuvent contenir des erreurs, des donnees perimees ou des hallucinations. Verifiez toujours les chiffres, prix et recommandations aupres de sources officielles. L'app ne garantit pas la precision de Gemini.",
                },
                "no_fiduciary": {
                    "title": "Pas de relation fiduciaire",
                    "body": "L'utilisation de l'app ne cree aucune relation de conseil, gestion ou intermediation entre vous et PluriFin. Nous ne recevons pas de mandat, ne gerons pas de capital, n'executons pas d'ordres pour vous.",
                },
                "risk": {
                    "title": "Risque de marche",
                    "body": "Les investissements peuvent perdre de la valeur. Les performances passees ne garantissent pas les resultats futurs. L'exposition a des instruments complexes (derives, levier, crypto) peut entrainer la perte totale du capital.",
                },
            },
            "checks": {
                "not_advice": "Je comprends que l'app ne fournit pas de conseil financier.",
                "not_fiduciary": "Je comprends que PluriFin ne gere pas mon capital.",
                "own_responsibility": "J'assume la responsabilite de mes decisions d'investissement.",
            },
        },
        "documents": {
            "title": "Documents legaux",
            "copy": "Copier le lien",
            "url_copied": "Lien copie dans le presse-papiers.",
            "privacy": {
                "title": "Politique de confidentialite",
                "description": "Quelles donnees l'app collecte, ou elles vivent et comment exercer vos droits RGPD.",
            },
            "terms": {
                "title": "Conditions d'utilisation",
                "description": "Conditions d'utilisation de l'app, y compris les limitations de responsabilite.",
            },
            "disclaimer": {
                "title": "Avertissement financier",
                "description": "Relisez le texte de l'avertissement accepte pendant l'onboarding.",
            },
            "licenses": {
                "title": "Licences open source",
                "description": "Liste des bibliotheques tierces incluses dans l'app.",
                "legalese": "Portfolio Manager (PluriFin) - Copyright (C) 2026 Filippo Salemi.",
            },
        },
    },
    "de": {
        "banner": {
            "ai_disclaimer": "KI-Inhalte sind keine Finanzberatung. Entscheidungen und Verantwortung liegen bei dir.",
        },
        "disclaimer": {
            "title": "Finanzhinweis",
            "intro": "Bitte sorgfaeltig lesen, bevor du die App nutzt. Bestaetige, dass du jeden Punkt verstanden hast.",
            "cta_accept": "Ich akzeptiere und moechte fortfahren",
            "sections": {
                "no_advice": {
                    "title": "Keine Finanzberatung",
                    "body": "Portfolio Manager ist ein Informationswerkzeug. Inhalte und Analysen in der App sind keine Finanz-, Steuer- oder Rechtsberatung gemaess TUF (italienisches D.Lgs. 58/1998) oder vergleichbaren Vorschriften. Entscheide stets mit einem zugelassenen Fachmann.",
                },
                "ai_warning": {
                    "title": "Grenzen der KI-Analyse",
                    "body": "KI-Antworten koennen Fehler, veraltete Daten oder Halluzinationen enthalten. Pruefe Zahlen, Preise und Empfehlungen immer mit offiziellen Quellen. Die App garantiert die Genauigkeit von Gemini in keiner Weise.",
                },
                "no_fiduciary": {
                    "title": "Kein Treuhandverhaeltnis",
                    "body": "Die Nutzung der App begruendet kein Berater-, Vermoegensverwaltungs- oder Vermittlungsverhaeltnis zwischen dir und PluriFin. Wir nehmen keine Auftraege an, verwalten kein Kapital und fuehren keine Auftraege aus.",
                },
                "risk": {
                    "title": "Marktrisiko",
                    "body": "Investitionen koennen an Wert verlieren. Frueheres Verhalten ist keine Garantie fuer die Zukunft. Komplexe Instrumente (Derivate, Hebel, Krypto) koennen zum Totalverlust des Kapitals fuehren.",
                },
            },
            "checks": {
                "not_advice": "Mir ist klar, dass die App keine Finanzberatung bietet.",
                "not_fiduciary": "Mir ist klar, dass PluriFin mein Kapital nicht verwaltet.",
                "own_responsibility": "Ich uebernehme die Verantwortung fuer meine Anlageentscheidungen.",
            },
        },
        "documents": {
            "title": "Rechtliche Dokumente",
            "copy": "Link kopieren",
            "url_copied": "Link in die Zwischenablage kopiert.",
            "privacy": {
                "title": "Datenschutzerklaerung",
                "description": "Welche Daten die App erhebt, wo sie liegen und wie du deine DSGVO-Rechte ausuebst.",
            },
            "terms": {
                "title": "Nutzungsbedingungen",
                "description": "Bedingungen fuer die Nutzung der App, einschliesslich Haftungsbeschraenkungen.",
            },
            "disclaimer": {
                "title": "Finanzhinweis",
                "description": "Lies den Hinweistext, den du beim Onboarding akzeptiert hast, erneut nach.",
            },
            "licenses": {
                "title": "Open-Source-Lizenzen",
                "description": "Liste der in der App enthaltenen Drittanbieter-Bibliotheken.",
                "legalese": "Portfolio Manager (PluriFin) - Copyright (C) 2026 Filippo Salemi.",
            },
        },
    },
    "pt": {
        "banner": {
            "ai_disclaimer": "O conteudo de IA nao e aconselhamento financeiro. Decisoes e responsabilidade sao suas.",
        },
        "disclaimer": {
            "title": "Aviso financeiro",
            "intro": "Leia com atencao antes de usar o app. Confirme que entendeu cada ponto.",
            "cta_accept": "Aceito e quero continuar",
            "sections": {
                "no_advice": {
                    "title": "Nao e aconselhamento financeiro",
                    "body": "O Portfolio Manager e uma ferramenta informativa. O conteudo e as analises mostradas no app nao constituem aconselhamento financeiro, fiscal ou juridico segundo o TUF (D.Lgs. 58/1998 italiano) ou normas equivalentes. Decida sempre com um profissional habilitado.",
                },
                "ai_warning": {
                    "title": "Limites da analise IA",
                    "body": "As respostas da IA podem conter erros, dados desatualizados ou alucinacoes. Verifique sempre numeros, precos e recomendacoes com fontes oficiais. O app nao garante a precisao do Gemini.",
                },
                "no_fiduciary": {
                    "title": "Sem relacao fiduciaria",
                    "body": "O uso do app nao cria nenhuma relacao de aconselhamento, gestao ou intermediacao entre voce e a PluriFin. Nao recebemos mandato, nao gerimos capital, nao executamos ordens em seu nome.",
                },
                "risk": {
                    "title": "Risco de mercado",
                    "body": "Investimentos podem perder valor. Performance passada nao garante resultados futuros. Exposicao a instrumentos complexos (derivativos, alavancagem, cripto) pode causar perda total do capital.",
                },
            },
            "checks": {
                "not_advice": "Entendo que o app nao fornece aconselhamento financeiro.",
                "not_fiduciary": "Entendo que a PluriFin nao gere meu capital.",
                "own_responsibility": "Assumo a responsabilidade pelas minhas decisoes de investimento.",
            },
        },
        "documents": {
            "title": "Documentos legais",
            "copy": "Copiar link",
            "url_copied": "Link copiado para a area de transferencia.",
            "privacy": {
                "title": "Politica de Privacidade",
                "description": "Que dados o app coleta, onde ficam e como exercer seus direitos LGPD/RGPD.",
            },
            "terms": {
                "title": "Termos de servico",
                "description": "Condicoes de uso do app, incluindo limitacoes de responsabilidade.",
            },
            "disclaimer": {
                "title": "Aviso financeiro",
                "description": "Releia o texto do aviso aceito durante o onboarding.",
            },
            "licenses": {
                "title": "Licencas open source",
                "description": "Lista das bibliotecas de terceiros incluidas no app.",
                "legalese": "Portfolio Manager (PluriFin) - Copyright (C) 2026 Filippo Salemi.",
            },
        },
    },
}


def inject(lang: str) -> None:
    path = TRANSLATIONS / f"{lang}.json"
    raw = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)

    # 1. settings.about.legal_documents
    settings_about = raw.get("settings", {}).get("about")
    if settings_about is None:
        raise SystemExit(f"{lang}: settings.about block missing")
    if "legal_documents" not in settings_about:
        # Re-build the OrderedDict so legal_documents lands right after
        # review_onboarding (and before onboarding_reset_message) for
        # readability in `git diff`.
        new_about = OrderedDict()
        for key, value in settings_about.items():
            new_about[key] = value
            if key == "review_onboarding":
                new_about["legal_documents"] = LEGAL_DOCUMENTS_LABEL[lang]
        raw["settings"]["about"] = new_about

    # 2. root-level legal block
    if "legal" not in raw:
        raw["legal"] = LEGAL_BLOCKS[lang]

    path.write_text(
        json.dumps(raw, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"  patched {lang}.json")


def main() -> None:
    if not TRANSLATIONS.exists():
        raise SystemExit(f"missing {TRANSLATIONS}")
    for lang in LANGS:
        inject(lang)
    print("done.")


if __name__ == "__main__":
    main()
